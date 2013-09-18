express = require 'express'
url = require 'url'
nomo = require('node-monkey').start()
app = express()
data = require './dummy-data'


app.use(express.static(__dirname + '/public'))
app.use(express.bodyParser())

# GET

app.get '/api/:type', (req, res) ->
	type = req.params.type
	collection = data[type]
	console.log 'foobar'
	ids = req.query.ids
	if not ids
		out = collection
	else
		ids = makeIdArray ids
		console.log ids
		out = []
		for model in collection
			if ids.indexOf(model.id) >= 0
				out.push model

	if out.length is 1 then out = out[0]

	res.writeHead 200, { 'Content-type': 'application/json' }
	res.end JSON.stringify(out)

app.post '/api/:type', (req, res) ->
	type = req.params.type
	biggestId = 0
	for item in data[type]
		if item.id > 0 then biggestId = item.id
	atts = req.body
	atts.id = biggestId + 1
	data[type].push atts

	res.writeHead 200, { 'Content-type': 'application/json' }
	res.end JSON.stringify atts






# Convenience
makeIdArray = (ids) ->
	ids = ids.split ','
	for id, i in ids
		ids[i] = parseInt id

app.listen 3000