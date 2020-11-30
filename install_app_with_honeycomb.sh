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
    "fastify": "^3.8.0",
    "honeycomb-beeline": "^2.5.0",
    "redis": "^3.0.2"
  }
}
EOT

cat <<EOT >> index.js
require('honeycomb-beeline') ({
  writeKey: '*** API KEY ***',
  dataset: 'fastify-cluster',
  serviceName: 'turnomatic-distribuido-grupo2'
});

const redis = require('redis')
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
        const fastify = require('fastify')({ logger: false })

        // Declare a route
        fastify.get('/turno/:id', answer)

        // Run the server!
        const start = async () => {
                try {
                        await fastify.listen(port, hostname)
                        fastify.log.info('server listening on \${fastify.server.address().port}')
                } catch (err) {
                        fastify.log.error(err)
                        process.exit(1)
                }
        }
        start()
}

async function answer(request, reply) {
        const id = request.params.id
        return await getRedisResult(id)
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
