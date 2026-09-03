import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { describeTools, parseInvoke } from "../src/lib/agent.ts";

describe("agent HTTP helpers", () => {
  it("parses invoke name and arguments aliases", () => {
    assert.deepEqual(parseInvoke({ name: "list_movies", arguments: { query: "Heat" } }), {
      name: "list_movies",
      args: { query: "Heat" }
    });
    assert.deepEqual(parseInvoke({ tool: "whoami", args: {} }), {
      name: "whoami",
      args: {}
    });
    assert.deepEqual(parseInvoke({ name: "undo", input: { undoId: "abc" } }), {
      name: "undo",
      args: { undoId: "abc" }
    });
    assert.equal(parseInvoke({}).name, "");
  });

  it("lists mov and pod tools a VM agent can call", () => {
    const tools = describeTools();
    const names = tools.map((tool) => tool.name);
    assert.ok(names.includes("list_movies"));
    assert.ok(names.includes("set_movie_saved"));
    assert.ok(names.includes("follow_podcast"));
    assert.ok(names.includes("undo"));
    assert.ok(tools.every((tool) => tool.description && tool.kind));
  });
});
