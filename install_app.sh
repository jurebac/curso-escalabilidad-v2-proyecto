#! /bin/bash
mkdir /opt/turnomatic-distribuido
cd /opt/turnomatic-distribuido

cat <<EOT >> package.json
{
  "name": "turnomatic-distribuido",
  "version": "0.0.1",
  "description": "A distributed turnomatic",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.17.1",
    "redis": "^3.0.2"
  }
}
EOT

cat <<EOT >> index.js
const redis = require('redis')
const http = require('http')
const cluster = require('cluster');
const numCPUs = require('os').cpus().length;

const hostname = '0.0.0.0'
const port = 7017
const redisHost = 'service.pinchito.es'
const redisPort = 7079
let client = null
let turno = 0

cluster.schedulingPolicy = cluster.SCHED_NONE

if (cluster.isMaster) {
	fork()
} else {
	startServer()
}

function fork() {
	console.log('Master \${process.pid} is running');

	// Fork workers.
	for (let i = 0; i < numCPUs; i++) {
		cluster.fork();
	}

	cluster.on('exit', (worker, code, signal) => {
		console.log('worker \${worker.process.pid} died');
	});
}

function startServer() {
	const server = http.createServer(answer)

	server.listen(port, hostname, () => {
		console.log('Server running at http://\${hostname}:\${port}/')
	})
}

function answer(request, response) {
	const paths = request.url.split('/')
	if (paths.length < 3 || paths[0] !== '' || paths[1] != 'turno') {
		response.statusCode = 400
		response.end(JSON.stringify({error: 'Invalid URL \${request.url}'}, null, '\t'))
		return
	}
	const id = paths[2]
	getRedisResult(id).then(result => {
		response.statusCode = 200
		response.setHeader('Content-Type', 'application/json')
		response.end(JSON.stringify(result, null, '\t'))
	}).catch(error => {
		console.error(error)
		response.statusCode = 500
		response.end(JSON.stringify({error}))
	})
}

function getRedisResult(id) {
	return new Promise((resolve, reject) => {
		if (!client) {
			initRedis()
		}
		client.incr(id, (error, result) => {
			if (error) return reject(error)
			resolve({id, turno: result})
		})
	})
}

function initRedis() {
	client = redis.createClient({
		host: redisHost,
		port: redisPort,
	})
	client.on('error', function(error) {
		console.error(error)
	})
}
EOT

npm install
npm start
