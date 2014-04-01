logger = require 'logger-sharelatex'
fs = require 'fs'
crypto = require 'crypto'
Settings = require('settings-sharelatex')
SubscriptionFormatters = require('../Features/Subscription/SubscriptionFormatters')
querystring = require('querystring')

fingerprints = {}
Path = require 'path'
jsPath =
	if Settings.useMinifiedJs
		"minjs/"
	else
		"js/"

logger.log "Generating file fingerprints..."
for path in [
    "#{jsPath}libs/require.js",
    "#{jsPath}ide.js",
    "#{jsPath}main.js",
    "#{jsPath}list.js",
    "#{jsPath}libs/pdf.js",
    "#{jsPath}libs/pdf.worker.js",
    "stylesheets/mainStyle.css",
    "brand/plans.css"
]
	filePath = Path.join __dirname, "../../../", "public/#{path}"
	exists = fs.existsSync filePath
	if exists
		content = fs.readFileSync filePath
		hash = crypto.createHash("md5").update(content).digest("hex")
		logger.log "#{filePath}: #{hash}"
		fingerprints[path] = hash
	else
		logger.log filePath:filePath, "file does not exist for fingerprints"
	

module.exports = (app)->
	app.use (req, res, next)->
		res.locals.session = req.session
		next()

	app.use (req, res, next)-> 
		res.locals.jsPath = jsPath
		next()

	app.use (req, res, next)-> 
		res.locals.settings = Settings
		next()

	app.use (req, res, next)->
		res.locals.getSiteHost = ->
			Settings.siteUrl.substring(Settings.siteUrl.indexOf("//")+2)
		next()

	app.use (req, res, next)->
		res.locals.formatProjectPublicAccessLevel = (privlageLevel)->
			formatedPrivlages = private:"Private", readOnly:"Public: Read Only", readAndWrite:"Public: Read and Write"
			return formatedPrivlages[privlageLevel] || "Private"
		next()

	app.use (req, res, next)-> 
		res.locals.buildReferalUrl = (referal_medium) ->
			url = Settings.siteUrl
			if req.session? and req.session.user? and req.session.user.referal_id?
				url+="?r=#{req.session.user.referal_id}&rm=#{referal_medium}&rs=b" # Referal source = bonus
			return url
		res.locals.getReferalId = ->
			if req.session? and req.session.user? and req.session.user.referal_id
				return req.session.user.referal_id
		res.locals.getReferalTagLine = ->
			tagLines = [
				"Roar!"
				"Shout about us!"
				"Please recommend us"
				"Tell the world!"
				"Thanks for using ShareLaTeX"
			]
			return tagLines[Math.floor(Math.random()*tagLines.length)]
		res.locals.getRedirAsQueryString = ->
			if req.query.redir?
				return "?#{querystring.stringify({redir:req.query.redir})}"
			return ""
		next()

	app.use (req, res, next) ->
		res.locals.csrfToken = req.session._csrf
		next()

	app.use (req, res, next)-> 
		res.locals.fingerprint = (path) ->
			if fingerprints[path]?
				return fingerprints[path]
			else
				logger.err "No fingerprint for file: #{path}"
				return ""
		next()
	app.use (req, res, next)-> 
		res.locals.formatPrice = SubscriptionFormatters.formatPrice
		next()

	app.use (req, res, next)->
		if req.session.user?
			res.locals.user =
				email: req.session.user.email
				first_name: req.session.user.first_name
				last_name: req.session.user.last_name
			if req.session.justRegistered
				res.locals.justRegistered = true
				delete req.session.justRegistered
			if req.session.justLoggedIn
				res.locals.justLoggedIn = true
				delete req.session.justLoggedIn
		res.locals.gaToken       = Settings.analytics?.ga?.token
		res.locals.tenderUrl     = Settings.tenderUrl
		next()

	app.use (req, res, next) ->
		if req.query? and req.query.scribtex_path?
			res.locals.lookingForScribtex = true
			res.locals.scribtexPath = req.query.scribtex_path
		next()



