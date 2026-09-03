import assert from "node:assert/strict";
import { createVerify, generateKeyPairSync } from "node:crypto";
import { describe, it } from "node:test";
import {
  buildApnsPayload,
  createApnsJwt,
  isInvalidDeviceToken,
  isTransientApnsStatus,
  normalizeDeviceToken,
  normalizePem,
  sendApnsNotification,
  topicForApp,
  type ApnsPost
} from "../src/lib/apns.ts";

const testKey = () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  return {
    privatePem: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    publicKey
  };
};

describe("normalizeDeviceToken", () => {
  it("accepts hex tokens and strips formatting", () => {
    const raw = "<Aa Bb Cc Dd Ee Ff 00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF 00 11 22 33 44 55 66 77 88 99>";
    assert.equal(normalizeDeviceToken(raw), "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899");
  });

  it("rejects short or non-hex tokens", () => {
    assert.equal(normalizeDeviceToken("not-a-token"), null);
    assert.equal(normalizeDeviceToken("aabbcc"), null);
  });
});

describe("normalizePem", () => {
  it("turns escaped newlines into a PEM block", () => {
    const pem = normalizePem("-----BEGIN PRIVATE KEY-----\\nABC\\n-----END PRIVATE KEY-----");
    assert.match(pem, /BEGIN PRIVATE KEY/);
    assert.ok(pem.includes("\n"));
  });
});

describe("createApnsJwt", () => {
  it("signs an ES256 token Apple will accept", () => {
    const { privatePem, publicKey } = testKey();
    const jwt = createApnsJwt({
      key: privatePem,
      keyId: "ABC123DEFG",
      teamId: "TEAM12ID34",
      iat: 1_700_000_000
    });
    const [header, payload, signature] = jwt.split(".");
    assert.deepEqual(JSON.parse(Buffer.from(header, "base64url").toString()), {
      alg: "ES256",
      kid: "ABC123DEFG"
    });
    assert.deepEqual(JSON.parse(Buffer.from(payload, "base64url").toString()), {
      iss: "TEAM12ID34",
      iat: 1_700_000_000
    });
    const verify = createVerify("SHA256");
    verify.update(`${header}.${payload}`);
    verify.end();
    assert.equal(
      verify.verify({ key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url")),
      true
    );
  });
});

describe("topicForApp", () => {
  it("uses the per-app bundle ids", () => {
    assert.equal(
      topicForApp("watchedit", {
        apnsBundleIdMov: "Carambula-Projects.WatchedIt",
        apnsBundleIdPod: "Carambula-Projects.PodLink"
      }),
      "Carambula-Projects.WatchedIt"
    );
    assert.equal(
      topicForApp("podlink", {
        apnsBundleIdMov: "Carambula-Projects.WatchedIt",
        apnsBundleIdPod: "Carambula-Projects.PodLink"
      }),
      "Carambula-Projects.PodLink"
    );
  });
});

describe("buildApnsPayload", () => {
  it("puts the alert on aps and keeps episode fields", () => {
    assert.deepEqual(
      buildApnsPayload({
        title: "The Rewatchables",
        body: "Fargo",
        type: "priority_podcasts",
        payload: { podcastId: "itunes-1", episodeTitle: "Fargo", publishDate: "2026-09-01" }
      }),
      {
        aps: { alert: { title: "The Rewatchables", body: "Fargo" }, sound: "default" },
        type: "priority_podcasts",
        podcastId: "itunes-1",
        episodeTitle: "Fargo",
        publishDate: "2026-09-01"
      }
    );
  });
});

describe("APNs status helpers", () => {
  it("retries server errors and drops dead tokens", () => {
    assert.equal(isTransientApnsStatus(503), true);
    assert.equal(isTransientApnsStatus(400), false);
    assert.equal(isInvalidDeviceToken({ status: 410, reason: "Unregistered" }), true);
    assert.equal(isInvalidDeviceToken({ status: 403, reason: "InvalidProviderToken" }), false);
  });
});

describe("sendApnsNotification", () => {
  it("posts to production and retries sandbox on BadDeviceToken", async () => {
    const hosts: string[] = [];
    const post: ApnsPost = async (input) => {
      hosts.push(input.host);
      assert.match(input.token, /^[0-9a-f]{64}$/);
      assert.equal(input.topic, "Carambula-Projects.PodLink");
      assert.equal(input.jwt, "test-jwt");
      assert.equal((input.payload.aps as { alert: { title: string } }).alert.title, "Show");
      if (input.host.includes("sandbox")) {
        return { status: 200 };
      }
      return { status: 400, reason: "BadDeviceToken" };
    };
    const result = await sendApnsNotification(
      {
        token: "A".repeat(64),
        app: "podlink",
        title: "Show",
        body: "Episode",
        type: "priority_podcasts"
      },
      post,
      {
        jwt: () => "test-jwt",
        topic: (app) => (app === "podlink" ? "Carambula-Projects.PodLink" : "Carambula-Projects.WatchedIt"),
        production: true
      }
    );
    assert.equal(result.status, 200);
    assert.deepEqual(hosts, ["api.push.apple.com", "api.sandbox.push.apple.com"]);
  });
});
