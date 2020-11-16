#! /bin/bash
mkdir app
cd app
npm init --yes
npm install express --save
npm install redis --save

cat <<EOT >> index.js
const express = require("express");
const redis = require("redis");

const app = express();
//const redis_client = redis.createClient();

//Healthcheck para ELB
app.get('/', function(req, res) {
  res.sendStatus(200);
});

app.get('/turno/:id', function (req, res) {
  var objResponse = {
    id: "grupo",
    turno: 0
  };

  /*redis_client.incr('counter');
  redis_client.get('counter', function(err, reply) {
    objResponse.turno = reply;
  });*/

  objResponse.id += req.params.id;
  res.json(objResponse);
});

app.listen(3000, () => {
 console.log("El servidor está inicializado en el puerto 3000");
});
EOT

node index.js

