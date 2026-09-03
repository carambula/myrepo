import { AgentError, TOOLS, toolsForScopes } from './protocol.js';

/**
 * Minimal MCP stdio server (JSON-RPC 2.0, newline-delimited or Content-Length).
 * No third-party dependencies.
 */

export function createMcpServer({ gateway, token, stdin = process.stdin, stdout = process.stdout }) {
  let buffer = Buffer.alloc(0);
  let framed = null;

  const write = (message) => {
    const body = Buffer.from(JSON.stringify(message), 'utf8');
    if (framed) {
      stdout.write(`Content-Length: ${body.length}\r\n\r\n`);
      stdout.write(body);
    } else {
      stdout.write(`${body}\n`);
    }
  };

  const respond = (id, result) => {
    if (id === undefined || id === null) return;
    write({ jsonrpc: '2.0', id, result });
  };

  const fail = (id, code, message, data) => {
    if (id === undefined || id === null) return;
    write({ jsonrpc: '2.0', id, error: { code, message, data } });
  };

  const handle = async (message) => {
    if (!message || message.jsonrpc !== '2.0' || !message.method) return;
    const { id, method, params = {} } = message;
    try {
      if (method === 'initialize') {
        respond(id, {
          protocolVersion: params.protocolVersion || '2024-11-05',
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: 'min-apps-agent', version: '1.0.0' },
        });
        return;
      }
      if (method === 'notifications/initialized' || method === 'initialized') {
        return;
      }
      if (method === 'ping') {
        respond(id, {});
        return;
      }
      if (method === 'tools/list') {
        const connection = gateway.authenticate(token);
        const allowed = new Set(toolsForScopes(connection.scopes).map((tool) => tool.name));
        respond(id, {
          tools: TOOLS.filter((tool) => allowed.has(tool.name)).map((tool) => ({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.inputSchema,
          })),
        });
        return;
      }
      if (method === 'tools/call') {
        const name = params.name;
        const args = params.arguments || {};
        const result = await gateway.call(token, name, args);
        respond(id, {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
          structuredContent: result,
        });
        return;
      }
      fail(id, -32601, `Method not found: ${method}`);
    } catch (error) {
      const isAgent = error instanceof AgentError;
      fail(id, isAgent ? -32000 : -32603, error.message, isAgent ? error.toJSON() : undefined);
    }
  };

  const consume = async () => {
    if (framed === false) {
      const text = buffer.toString('utf8');
      const lines = text.split('\n');
      buffer = Buffer.from(lines.pop() ?? '', 'utf8');
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        await handle(JSON.parse(trimmed));
      }
      return;
    }

    while (true) {
      const headerEnd = buffer.indexOf('\r\n\r\n');
      if (headerEnd === -1) {
        const newline = buffer.indexOf('\n');
        if (newline !== -1 && framed !== true) {
          framed = false;
          await consume();
        }
        return;
      }
      framed = true;
      const header = buffer.slice(0, headerEnd).toString('utf8');
      const match = header.match(/Content-Length:\s*(\d+)/i);
      if (!match) {
        buffer = buffer.slice(headerEnd + 4);
        continue;
      }
      const length = Number(match[1]);
      const start = headerEnd + 4;
      if (buffer.length < start + length) return;
      const body = buffer.slice(start, start + length).toString('utf8');
      buffer = buffer.slice(start + length);
      await handle(JSON.parse(body));
    }
  };

  stdin.on('data', async (chunk) => {
    buffer = Buffer.concat([buffer, Buffer.from(chunk)]);
    try {
      await consume();
    } catch (error) {
      write({
        jsonrpc: '2.0',
        error: { code: -32700, message: error.message },
      });
    }
  });

  return { write, handle };
}
