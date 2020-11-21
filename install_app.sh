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
const express = require("express");

const app = express();

let count = 0;

//Healthcheck para ELB
app.get('/', function(req, res) {
  res.sendStatus(200);
});

app.get('/turno/:id', function (req, res) {
  var objResponse = {
    id: "grupo",
    turno: 0
  };

  objResponse.id += req.params.id;
  objResponse.turno = ++count;
  res.json(objResponse);
});

app.listen(3000, () => {
 console.log("El servidor está inicializado en el puerto 3000");
});
EOT

npm install
npm start

