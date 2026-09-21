import http from 'node:http'

const server = http.createServer((request, response) => {
  const url = new URL(request.url ?? '/', 'http://127.0.0.1:5081')
  response.setHeader('Content-Type', 'application/json')
  response.setHeader('Set-Cookie', ['session=abc123; HttpOnly; Path=/', 'theme=dark; SameSite=Lax; Path=/'])
  response.end(JSON.stringify({
    method: request.method,
    authorization: request.headers.authorization ?? null,
    apiKey: request.headers['x-api-key'] ?? null,
    cookie: request.headers.cookie ?? null,
    accept: request.headers.accept ?? null,
    userAgent: request.headers['user-agent'] ?? null,
    query: Object.fromEntries(url.searchParams),
  }))
})

server.listen(5081, '127.0.0.1')
