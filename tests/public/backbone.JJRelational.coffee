###*
 * Backbone JJRelational
 * v0.2.9
 *
 * A relational plugin for Backbone JS that provides one-to-one, one-to-many and many-to-many relations between Backbone models.
 *
 * Tested with Backbone v1.0.0 and Underscore v.1.5.0
 * 
###

do () ->
	"use strict"

	# CommonJS shim

	if typeof window is 'undefined'
		_ = require 'underscore'
		Backbone = require 'backbone' 
		exports = Backbone
		typeof module is 'undefined' || (module.exports = exports)
	else
		_ = window._
		Backbone = window.Backbone
		exports = window

	that = @

	# !-
	# ! Backbone.JJStore
	# !-
	###*
	 * 
	 * The Store - well, stores all models in it.
	 * On creation, a model registers itself in the store by its `storeIdentifier`-attribute.
	 * Backbone JJStore provides some methods to get models by id/cid, for example, etc.
	 * 
	###

	# Basic setup
	
	Backbone.JJStore = {}
	Backbone.JJStore.Models = {}
	Backbone.JJStore.Events = _.extend {}, Backbone.Events

	###*
	 * Adds a store for the given `storeIdentifier` if one doesn't exist yet.
	 * @param  {String} storeIdentifier
	 * @return {Backbone.Collection}                 The matching store array
	###
	Backbone.JJStore.__registerModelType = (storeIdentifier) ->
		@.Models[storeIdentifier] = new Backbone.Collection() unless @.Models[storeIdentifier]
		@.Models[storeIdentifier]

	###*
	 * Adds a model to its store if it's not present yet.
	 * @param  {Backbone.JJRelationalModel} model    The model to register
	 * @return {Boolean} true
	###
	Backbone.JJStore.__registerModelInStore = (model) ->
		store = @.__registerModelType model.storeIdentifier
		if not store.get(model)
			store.add model, { silent: true }
			Backbone.JJStore.Events.trigger('added:' + model.storeIdentifier, model)
		true

	###*
	 * Removes a model from its store if present.
	 * @param  {Backbone.JJRelationalModel} model    The model to remove
	 * @return {Boolean} true
	###
	Backbone.JJStore.__removeModelFromStore = (model) ->
		@.Models[model.storeIdentifier].remove model
		true

	## Convenience functions

	Backbone.JJStore._byId = (store, id) ->
		if _.isString store then store = @.Models[store]
		if store
			return store.get id
		null


	# !-
	# ! Backbone JJRelationalModel
	# !-
	###*
	 *
	 * The main part
	 * 
	###

	# ! Basic setup

	Backbone.JJRelational = {}

	Backbone.JJRelational.VERSION = '0.2.9'

	Backbone.JJRelational.Config = {
		url_id_appendix : '?ids='
		# if this is true and you create a new model with an id that already exists in the store,
		# the existing model will be updated and returned instead of a new one
		work_with_store	: true
	}

	Backbone.JJRelational.CollectionTypes = {}
 
	# ! General functions


	###*
	 * Find a type on the global object by name. Splits name on dots.
	 * (i.e. 'Store.Models.MyModel' will return exports['Store']['Models']['MyModel'])
	 * @param  {String} name                           Name to look for
	 * @return {mixed}                                 Global var
	###
	Backbone.JJRelational.__getObjectByName = (name) ->
		type = _.reduce name.split('.'), (memo, val) ->
			memo[val]
		, exports

		if type isnt exports then return type else return null

	###*
	 * Registers one or many collection-types, in order to build a correct collection instance for many-relations.
	 * @param  {Object} collTypes                      key => value pairs, where `key` is the name under which to store the collection type (`value`)
	 * @return {Boolean}           					   Success or not.
	###
	Backbone.JJRelational.registerCollectionTypes = (collTypes) ->
		if not _.isObject(collTypes) then return false

		for name, collection of collTypes
			Backbone.JJRelational.CollectionTypes[name] = collection
		true

	###*
	 * Returns a collection type by the registered name.
	 * If none is found, Backbone.Collection will be returned.
	 * @param  {String} name                           Name under which the collection type is stored
	 * @return {Backbone.Collection}                   Found collection type or Backbone.Collection
	###	
	Backbone.JJRelational.__getCollectionType = (name) ->
		for n, coll of Backbone.JJRelational.CollectionTypes
			if n is name then return coll

		return Backbone.Collection


	###*
	 * Backbone.JJRelationalModel
	 *
	 * The main model extension of Backbone.Model
	 * Here come the good parts. :)
	 * @type {Backbone.JJRelationalModel}
	 * 
	###
	Backbone.Model.prototype.__save = Backbone.Model.prototype.save
	Backbone.JJRelationalModel = Backbone.Model.extend

		# This flag checks whether all relations have been installed. If false, some "`set`"-functionality is suppressed.
		relationsInstalled: false

		###*
		 * The constructor:
		 * The Model is built normally, then the relational attributes are set up and the model is registered in the store.
		 * After that, the relational attributes are populated (if present in argument `attributes`).
		 * At last, the creation of the model is triggered on Backbone.JJStore.Events. (e.g. 'created:MyModel')
		 * 
		 * @param  {Object} attributes                  Initial attributes.
		 * @param  {Object} options                     Options object.
		 * @return {Backbone.JJRelationalModel}         The freshly created model.
		###
		constructor: (attributes, options) ->
			# check if the model already exists in the store (by id)
			if Backbone.JJRelational.Config.work_with_store and _.isObject(attributes) and id = attributes[@.idAttribute]
				existModel = Backbone.JJStore._byId @.storeIdentifier, id

			if existModel
				# if the model exists, update the existing one and return it instead of a new model
				existModel.set attributes, options
				return existModel

			# usual Backbone.Model constructor
			Backbone.Model.apply(this, arguments)
			# set up the relational attributes
			@.__prepopulate_rel_atts()
			# put in store
			Backbone.JJStore.__registerModelInStore @
			# populate relations with attributes
			@.__populate_rels_with_atts(attributes, options)
			# trigger the creation
			Backbone.JJStore.Events.trigger 'created:' + @.storeIdentifier, @
			@

		###*
		 * Initializes the relational attributes and binds basic listeners.
		 * has_many and many_many get empty collections, with a `_relational`-property containing:
		 * `owner`, `ownerKey`, `reverseKey` and `idQueue`
		 * 
		 * @return {Backbone.JJRelationalModel}
		###
		__prepopulate_rel_atts: ->
			if @.relations
				for relation, i in @.relations
					relModel = relation.relatedModel

					# check includeInJSON
					relation.includeInJSON = if relation.includeInJSON then relation.includeInJSON else []
					relation.includeInJSON = if _.isArray(relation.includeInJSON) then relation.includeInJSON else [relation.includeInJSON]
					indexOfID = _.indexOf(relation.includeInJSON, 'id')
					if indexOfID >= 0 and @.idAttribute then relation.includeInJSON[indexOfID] = @.idAttribute

					# at first check if relatedModel is an instance of Backbone.JJRelationalModel or a string, in which case we should get it from the global object
					if relModel is undefined or relModel.prototype instanceof Backbone.JJRelationalModel is false
						if _.isString(relModel)
							# try to get it from the global object
							gObj = Backbone.JJRelational.__getObjectByName relModel
							if gObj and gObj.prototype instanceof Backbone.JJRelationalModel is true
								relModel = @.relations[i].relatedModel = gObj
							else
								throw new TypeError 'relatedModel "' + relModel + '" is neither a reference to a JJRelationalModel nor a string referring to an object in the global oject'
						else if _.isFunction(relModel)
							relModel = @.relations[i].relatedModel = relModel.call @


					value
					if relation and not isOneType(relation) and collType = Backbone.JJRelational.__getCollectionType relation.collectionType
						value = new collType()
						value._relational = 
							owner       : @
							ownerKey    : relation.key 
							reverseKey  : relation.reverseKey
							idQueue     : []
					else
						value = null
					@.attributes[relation.key] = value


					# bind any creations of the related model
					# @todo unbind JJStore Event on deletion of model
					Backbone.JJStore.Events.bind 'created:' + relModel.prototype.storeIdentifier, @.newModelInStore, @
				@.bind 'destroy', @._destroyAllRelations
			@.relationsInstalled = true
			@

		###
		 # Fills in any relational values that are present in the `attributes`-argument
		 # e.g. var m = new MyModel({ HasOneRelation : relationalModel });
		 #
		 # @param {Object} attributes
		 # @param {Object} options
		 #
		###
		__populate_rels_with_atts: (attributes, options) ->
			for key, value of attributes
				if relation = @.getRelationByKey key
					# check if the attribute is a whole collection and if that makes any sense
					if value instanceof Backbone.Collection is true
						throw new TypeError 'The attribute "' + key + '" is a collection. You should not replace whole collections in a relational attribute. Please use the direct reference to the model array (Backbone.Collection.models)'
					else
						value = if _.isArray value then value else [ value ]
						for v in value
							@.checkAndAdd v, relation, options
			@

		# ! Backbone core overrides

		###*
		 * Override "`save`" method.
		 * The concept is: When saving a model, it is checked whether it has any relations containing a 
		 * new model. If yes, the new model is saved first. When all new models have been saved, only
		 * then is the actual model saved.
		 * Relational collections are saved as an array of models + idQueue
		 * Concerning relations, the `includeInJSON`-property is used to generate the JSON object
		 * 
		 * @param  {String | Object} key                  See Backbone core
		 * @param  {mixed | Object} value                 See Backbone core
		 * @param  {Object} options                       (optional) See Backbone core
		 * @return {Backbone.$.ajax}
		###
		save: (key, value, options) ->
			attrs
			returnXhr = null
			attributes = @.attributes

			# Handle both '("key", value)' and '({key: value})` -style calls.'
			# this doesn't differ from Backbone core
			if _.isObject(key) or not key
				attrs = key
				options = value
			else if key isnt null
				attrs = {}
				attrs[key] = value
			options = if options then _.clone(options) else {}
			options.isSave = true

			# If we're not waiting and attributes exist, save acts as `set(attr).save(null, opts)`.
			if attrs and (not options or not options.wait) and not @.set(attrs, options) then return false

			options = _.extend {validate: true}, options
			
			# Do not persist invalid models
			if not this._validate(attrs,options) then return false

			# Set temporary attributes if `{wait: true}`
			if attrs and options.wait then @.attributes = _.extend({}, attributes, attrs)

			#
			# This is the actual save function that's called when all the new related models have been saved
			#
			actualSave = =>
				success = options.success

				# generate JSON
				# use `includeInJSON` for relations
				if not options.contentType then options.contentType = 'application/json'
				
				if not options.data then options.data = JSON.stringify(@.toJSON({isSave: true}))
				
				if options.parse is undefined then options.parse = true
				
				options.success = (resp, status, xhr) =>
					# Ensure attribtues are restored during synchronous saves
					@attributes = attributes

					serverAttrs = @.parse resp, options
					if options.wait then serverAttrs = _.extend(attrs || {}, serverAttrs)
					if _.isObject(serverAttrs) and not @.set(serverAttrs, options) then return false

					if success then success @, resp, options
					@.trigger 'sync', @, resp, options

				wrapError @, options

				method = if @.isNew() then 'create' else (if options.patch then 'patch' else 'update')
				if method is 'patch' then options.attrs = attrs
				xhr = @.sync method, @, options
				
				# Restore attributes
				if attrs and options.wait then @.attributes = attributes

				xhr

			# Okay, so here's actually happening it. When we're saving - and a model in a relation is not yet saved
			# we have to save the related model first. Only then can we save our actual model.
			# This goes down to infinity... ;)
			# If multiple models must be saved first, we need to check if everything's been saved, before calling "`actualSave`".
			
			# we need an array that stores models which must be ignored to prevent double saving...
			if not options.ignoreSaveOnModels then options.ignoreSaveOnModels = [@]
			relModelsToSave = []

			# checks if a model is new
			checkIfNew = (val) ->
				try
					if val and (val instanceof Backbone.JJRelationalModel) and val.url() and val.isNew() then relModelsToSave.push({model: val, done: false})
			# checks if all models have been saved. if yes, do the "`actualSave`"
			checkAndContinue = ->
				if _.isEmpty relModelsToSave then returnXhr = actualSave()
				done = true
				for obj in relModelsToSave
					if obj.done is false then done = false
				if done then returnXhr = actualSave()

			# iterate over relations and check if a model is new
			if @.relations
				for relation in @.relations
					val = @.get relation.key
					if isOneType relation
						checkIfNew val
					else if isManyType relation
						for model in val.models
							checkIfNew model

			# if we don't have any relational models to save, directly go to "`actualSave`"
			if _.isEmpty relModelsToSave then returnXhr = actualSave()

			# save every relational model that needs saving and add it to the `ignoreSaveOnModel` option.
			for obj in relModelsToSave
				if _.indexOf(options.ignoreSaveOnModels, obj.model) <= -1
					# add to options.ignoreSaveModels to avoid multiple saves on the same model
					options.ignoreSaveOnModels.push obj.model
					# clone options to avoid conflicts
					opts = _.clone options
					
					opts.success = (model, resp) ->
						for obj in relModelsToSave
							if obj.model.cid is model.cid then obj.done = true

						# trigger on JJStore.Events
						Backbone.JJStore.Events.trigger 'created:' + model.storeIdentifier, model
						# check if that's all and continue if yes
						checkAndContinue()
					obj.model.save({}, opts)
				else
					obj.done = true
					checkAndContinue()

			
			returnXhr

		###*
		 * Override "`set`" method.
		 * This is pretty much the most important override...
		 * It's almost exactly the same as the core `set` except for one small code block handling relations.
		 * See `@begin & @end edit` in the comments
		 *
		 * If `set` is the heart of the beast in Backbone, JJRelational makes sure it's not made of stone.
		 * 
		 * @param {String | Object} key                    See Backbone core
		 * @param {mixed | Object} val                     See Backbone core
		 * @param {Object} options                         (optional) Backbone core
		###
		set: (key, val, options) ->
			if key is null then return @

			# Handle both `"key", value` and `{key: value}` -style arguments.
			if typeof key is 'object'
				attrs = key
				options = val
			else
				attrs = {}
				attrs[key] = val
			
			options = options or {}

			# Run validation
			if not @._validate(attrs, options) then return false

			# Extract attributes and options
			unset = options.unset
			silent = options.silent
	
			changes = []
			changing = @._changing
			@._changing = true

			if not changing
				@._previousAttributes = _.clone @.attributes
				@.changed = {}
			current = @.attributes
			prev = @._previousAttributes

			# actual setting
			checkAndSet = (key, value) =>
				if not _.isEqual current[key], value then changes.push key
				if not _.isEqual prev[key], value then @.changed[key] = val else delete @.changed[key]
				###*
				 * @begin edit JJRelational
				###
				# check if it's a relation that is to be set
				if (relation = @.getRelationByKey key) and @.relationsInstalled
					# if yes, empty relation
					@._emptyRelation relation
					value = if _.isArray value then value else [value]
					for v in value
						# check the value and add it to the relation accordingly
						@.checkAndAdd(v, relation, options) unless unset
				else
					if unset then delete current[key] else current[key] = value
				###*
				 * @end edit JJRelational
				###

			# Trigger all relevant attribute changes
			triggerChanges = =>
				if not silent
					if changes.length then this._pending = true
					for change in changes
						@.trigger 'change:' + change, @, current[change], options

			# Check for changes of `id`
			# If changed, we have to trigger `change:{idAttribute}` early, so that any
			# collections can update their _byId lookups of this model
			if @.idAttribute of attrs
				@.id = attrs[@.idAttribute]
				checkAndSet @.idAttribute, attrs[@.idAttribute]
				# trigger early if necessary
				triggerChanges()
				# remove from changes to prevent triggering it twice
				i = changes.indexOf @.idAttribute
				if ~i then changes.splice i, 1
				delete attrs[@.idAttribute]


			# Check for changes of `id`
			if @.idAttribute of attrs then @.id = attrs[@.idAttribute]

			# iterate over the attributes to set
			for key, value of attrs
				checkAndSet key, value

			triggerChanges()

			if changing then return @
			if not silent
				while @._pending
					@._pending = false
					@.trigger 'change', @, options
			@._pending = false
			@._changing = false

			@

		###*
		 * Override "`_validate`" method.
		 * The difference is that it flattens relational collections down to its model array.
		 * 
		 * @param  {Object} attrs                            see Backbone core
		 * @param  {Object} options                          see Backbone core
		 * @return {Boolean}                                 see Backbone core
		###
		_validate: (attrs, options) ->
			if not options.validate or not @.validate then return true
			attrs = _.extend {}, @.attributes, attrs
			for relation in @.relations
				val = attrs[relation.key]
				if val instanceof Backbone.Collection is true then attrs[relation.key] = val.models
			error = @.validationError = @.validate(attrs, options) || null
			if not error then return true
			@.trigger 'invalid', @, error, _.extend(options || {}, {validationError: error})
			false

		###*
		 * Override `toJSON` method for relation handling.
		 * If it's for saving (`options.isSave == true`), then it uses the includeInJSON property of relations. 
		 * This can go down as many levels as required.
		 * If not, it just goes down one level.
		 * 
		 * @param  {Object} options                    Options object
		 * @return {Object}                            Final JSON object
		###
		toJSON: (options) ->
			options = options || {}
			# if options.withRelIDs, return the model with its related models represented only by ids
			if options.withRelIDs then return @.toJSONWithRelIDs()

			json = _.clone @.attributes
			# if options.bypass, return normal Backbone toJSON-function
			if options.bypass then return json

			if options.isSave
				for relation in @.relations
					# if this relation should not be included continue
					if options.scaffold and ( _.indexOf(options.scaffold, relation.key) < 0 ) then continue

					include = relation.includeInJSON

					key = relation.key
					relValue = @.get key
					if isOneType relation
						if relValue
							if (relValue instanceof relation.relatedModel is true)
								if include.length is 0
									json[relation.key] = relValue.toJSONWithRelIDs()
								else if include.length is 1
									json[relation.key] = relValue.get(include[0])
								else
									json[relation.key] = relValue.toJSON {isSave: true, scaffold:include}
							else
								# only id is present. check if 'id' is specified in includeInJSON
								json[relation.key] = if ( _.indexOf(include, relation.relatedModel.prototype.idAttribute) >=0 ) then relValue else null
						else
							json[relation.key] = null
					else if isManyType relation
						if include.length is 0
							json[relation.key] = relValue.toJSON {withRelIDs: true}
						else if include.length is 1						
							json[relation.key] = relValue.getArrayForAttribute include[0]
						else
							json[relation.key] = relValue.toJSON {isSave: true, scaffold:include}
							if _.indexOf(include, 'id') >= 0 then json[relation.key].push relValue._relational.idQueue 

			# e.g. for views
			else
				# go down one level
				for relation in @.relations
					relValue = @.get relation.key
					if isOneType relation
						json[relation.key] = if (relValue instanceof relation.relatedModel is true) then relValue.toJSONWithRelIDs() else relValue
					else if isManyType relation
						json[relation.key] = relValue.toJSON {withRelIDs: true}

			if options.scaffold
				json = _.pick.apply that, [json, options.scaffold]

			json

		# ! Managing functions

		###*
		 * Returns a JSON of the model with the relations represented only by ids.
		 * 
		 * @return {Object}                            Final JSON object
		###
		toJSONWithRelIDs: ->
			json = _.clone @.attributes
			for relation in @.relations
				relValue = @.get relation.key
				if isOneType relation
					json[relation.key] = if (relValue instanceof relation.relatedModel is true) then relValue.id else relValue
				else if isManyType relation
					json[relation.key] = relValue.getIDArray()
			json

		###*
		 * This function checks a given value and adds it to the relation accordingly.
		 * If it's a model, it adds it to the relation. If it's a set of attributes, it creates a new model
		 * and adds it. Otherwise it assumes that it must be the id, looks it up in the store (if there's
		 * already a model) or adds it to the relation's idQueue.
		 * 
		 * @param  {mixed}  val                              The value to check
		 * @param  {Object} rel                              The relation which to add the value to
		 * @param  {Object} options                          Options object
		 * @return {Backbone.JJRelationalModel}
		###
		checkAndAdd: (val, rel, options) ->
			options = options or {}
			relModel = rel.relatedModel
			if val instanceof relModel is true
				# is already a Model -> just add
				@.addToRelation val, rel, false
			else if _.isObject(val) and val instanceof Backbone.Model is false
				# is an object -> Model has to be created and populated -> then add
				newModel = new relModel val
				@.addToRelation newModel, rel, false
			else
				# must be the id. look it up in the store or add it to idQueue
				storeIdentifier = relModel.prototype.storeIdentifier
				if existModel = Backbone.JJStore._byId storeIdentifier, val
					# check if this model should be ignored. this is the case for example for collection.fetchIdQueue()
					if options.ignoreModel is existModel then return
					@.addToRelation existModel, rel, false
				else if isManyType rel
					@.get(rel.key).addToIdQueue val
				else if isOneType rel
					@.setHasOneRelation rel, val, true
			@

		###*
		 * This function is triggered by a newly created model (@see Backbone.JJRelationalModel.constructor)
		 * that has been registered in the store and COULD belong to a relation.
		 * 
		 * @param {Backbone.JJRelationalModel} model        The newly created model which triggered the event.
		###
		newModelInStore: (model) ->
			id = model.id
			if id
				# get the relation by the model's identifier
				relation = @.getRelationByIdentifier model.storeIdentifier
				if relation
					if isOneType relation
						# check if that one's needed overall
						if id is @.get relation.key
							@.addToRelation model, relation, false
					else if isManyType relation
						# check if id exists in idQueue
						relColl = @.get relation.key
						idQueue = relColl._relational.idQueue

						if _.indexOf(idQueue, id) > -1
							@.addToRelation model, relation, false
						
			undefined

		###*
		 * Adds a model to a relation.
		 * 
		 * @param {Backbone.JJRelationalModel} model         The model to add
		 * @param {String | Object} relation                 Relation object or relationKey
		 * @param {Boolean} silent                           Indicates whether to pass on the relation to the added model. (reverse set)
		 * @return {Backbone.JJRelationalModel}
		###
		addToRelation: (model, relation, silent) ->
			# if relation is not passed completely, it is treated as the key
			if not _.isObject relation then relation = @.getRelationByKey relation
		
			if relation and (model instanceof relation.relatedModel is true)
				# handling of has_one relation
				if isOneType relation
					if @.get(relation.key) isnt model
						@.setHasOneRelation relation, model, silent
				else if isManyType relation
					@.get(relation.key).add model, {silentRelation: silent}

			@

		###*
		 * Sets a value on a has_one relation.
		 * 
		 * @param {String | Object} relation                 Relation object or relationKey
		 * @param {mixed} val                                The value to set
		 * @param {Boolean} silentRelation                   Indicates whether to pass on the relation to the added model. (reverse set)
		###
		setHasOneRelation: (relation, val, silentRelation) ->
			if not _.isObject relation then relation = @.getRelationByKey relation
			prev = @.get relation.key
			@.attributes[relation.key] = val

			if silentRelation then return
			if prev instanceof relation.relatedModel is true then prev.removeFromRelation relation.reverseKey, @, true
			if val instanceof relation.relatedModel is true
				# pass on relation
				val.addToRelation @, relation.reverseKey, true
			@

		###*
		 * Removes a model from a relation
		 * @param  {String | Object} relation                 Relation object or relationKey
		 * @param  {Backbone.JJRelationalModel} model         The model to add
		 * @param  {Boolean} silent                           Indicates whether to pass on the relation to the added model. (reverse set)
		 * @return {Backbone.JJRelationalModel}
		###
		removeFromRelation: (relation, model, silent) ->
			# if relation is not passed completely, it is treated as the key
			if not _.isObject relation then relation = @.getRelationByKey relation
			
			if relation
				if isOneType relation
					@.setHasOneRelation relation, null, silent
				else if isManyType relation
					coll = @.get relation.key
					if (model instanceof relation.relatedModel is true)
						coll.remove model, {silentRelation:silent}
					else
						coll.removeFromIdQueue model
			@

		###*
		 * Completely empties a relation.
		 * 
		 * @param  {Object} relation
		 * @return {Backbone.JJRelationalModel}
		###
		_emptyRelation: (relation) ->
			if isOneType relation
				@.setHasOneRelation relation, null, false
			else if isManyType relation
				coll = @.get relation.key
				coll._cleanup()
			@

		###*
		 * Cleanup function that removes all listeners, empties relation and informs related models of removal
		 * 
		 * @return {Backbone.JJRelationalModel}
		###
		_destroyAllRelations: ->
			Backbone.JJStore.__removeModelFromStore @
			for relation in @.relations

				# remove listeners
				@.unbind 'destroy', @._destroyAllRelations
				Backbone.JJStore.Events.unbind 'created:' + relation.relatedModel.prototype.storeIdentifier, @.newModelInStore, @

				# inform relation of removal
				if isOneType(relation) and relModel = @.get(relation.key)
					@.setHasOneRelation relation, null, false             
				else if isManyType(relation)
					@.get(relation.key)._cleanup()
			@

		###*
		 * Helper function to get the length of the relational idQueue (for has_one: 0 || 1)
		 * 
		 * @param  {String | Object} relation                Relation object or relationKey
		 * @return {Integer}                                 Length of idQueue
		###
		getIdQueueLength: (relation) ->
			if not _.isObject relation then relation = @.getRelationByKey relation
			if relation
				if isOneType relation
					val = @.get relation.key
					if (not val) || (val instanceof relation.relatedModel is true) then return 0 else return 1
				else if isManyType relation
					return @.get(relation.key)._relational.idQueue.length
			0

		###*
		 * Clears the idQueue of a relation
		 * 
		 * @param  {String | Object} relation                 Relation object or relationKey
		 * @return {Backbone.JJRelationalModel}
		###
		clearIdQueue: (relation) ->
			if not _.isObject relation then relation = @.getRelationByKey relation
			if relation
				if isOneType relation
					val = @.get relation.key
					if val and (val instanceof relation.relatedModel is false) then @.set relation.key, null, {silentRelation: true}
				else if isManyType relation
					coll = @.get relation.key
					coll._relational.idQueue = []
			@

		###*
		 * Fetches missing related models, if their ids are known.
		 * 
		 * @param  {String | Object} relation                 Relation object or relationKey
		 * @param  {Object} options                           Options object
		 * @return {Backbone.$.ajax}
		###
		fetchByIdQueue: (relation, options) ->
			if not _.isObject relation then relation = @.getRelationByKey relation
			if relation
				if isManyType relation
					# pass this on to collection, it will handle the rest
					@.get(relation.key).fetchByIdQueue(options)
				else if isOneType relation
					id = @.get relation.key
					if id and (id instanceof relation.relatedModel is false)
						relModel = relation.relatedModel
						if options then options = _.clone(options) else options = {}

						# set the url
						url = getValue relModel.prototype, 'url'
						url += Backbone.JJRelational.Config.url_id_appendix + id
						options.url = url

						if options.parse is undefined then options.parse = true

						success = options.success
						options.success = (resp, status, xhr) =>
							# IMPORTANT: set the id in the relational attribute to null, so that the model won't be 
							# added twice to the relation (by Backbone.JJStore.Events trigger)
							@.setHasOneRelation relation, null, true
							options.ignoreModel = @
							model = new relModel relModel.prototype.parse(resp[0]), options
							@.set relation.key, model
							
							if success then success(model, resp)
							model.trigger 'sync', model, resp, options

						wrapError @, options
						return @.sync.call(@, 'read', @, options)
			@

		###*
		 * 
		 * @begin Helper methods
		 *
		###
		getRelationByKey: (key) ->
			for relation in @.relations
				if relation.key is key then return relation
			false

		getRelationByReverseKey: (key) ->
			for relation in @.relations
				if relation.reverseKey is key then return relation
			false

		getRelationByIdentifier: (identifier) ->
			for relation in @.relations
				if relation.relatedModel.prototype.storeIdentifier is identifier then return relation
			false

		# @end Helper methods


	# ! Backbone Collection

	###*
	 * Sums up "`fetchByIdQueue`"-calls on the same relation in a whole collection
	 * by collecting the idQueues of each model and firing a single request.
	 * The fetched models are just added to the store, so they will be added to the relation
	 * via the Backbone.JJStore.Events listener
	 * 
	 * @param  {String} relationKey                       Key of the relation
	 * @param  {Object} options                           Options object
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype.fetchByIdQueueOfModels = (relationKey, options) ->
		if @.model and (@.model.prototype instanceof Backbone.JJRelationalModel is true)
			relation = @.model.prototype.getRelationByKey relationKey
			relModel = relation.relatedModel
			idQueue = []

			# build up idQueue
			if isOneType relation
				@.each (model) ->
					val = model.get relationKey
					if val && val instanceof relModel is false
						# must be the id: add to idQueue
						idQueue.push val
			else if isManyType relation
				@.each (model) ->
					coll = model.get relationKey
					idQueue = _.union(idQueue, coll._relational.idQueue)

			# get and set the url on options
			if idQueue.length > 0
				options.url = getUrlForIdQueue relModel.prototype, idQueue
				if options.parse is undefined then options.parse = true

				success = options.success
				options.success = (resp, status, xhr) =>
					parsedObjs = []
					# check if there's a collection type for the relation. if yes, parse with it
					if relation.collectionType and (collType = Backbone.JJRelational.__getCollectionType relation.collectionType)
						parsedObjs = collType.prototype.parse(resp)
					else if _.isArray resp
						# parse each object in it with the related model's parse-function
						for respObj in resp
							if _.isObject respObj then parsedObjs.push relModel.prototype.parse(respObj)
					
					# build up the new models
					for parsedObj in parsedObjs
						new relModel parsedObj

					if success then success(@, resp)
					@.trigger 'sync', @, resp, options
	
				wrapError @, options
				return @.sync.call(this, 'read', this, options)

		# call success function no matter what
		if options.success then options.success(@)
		@


	###*
	 *
	 * Backbone.Collection hacks
	 * 
	###


	Backbone.Collection.prototype.__set = Backbone.Collection.prototype.set
	###*
	 * This "`set`" hack checks if the collection belongs to the relation of a model.
	 * If yes, handle the models accordingly.
	 * 
	 * @param {Array | Object | Backbone.Model} models         The models to set
	 * @param {Object} options                                 Options object
	###
	Backbone.Collection.prototype.set = (models, options) ->
		# check if this collection belongs to a relation
		if not @._relational then return @.__set models, options

		if @._relational
			# prepare options and models
			options || (options = {})
			if not _.isArray models
				models = [ models ] 

			modelsToAdd = []
			idsToRemove = []
			idsToAdd = []

			# check if models are instances of Backbone.Model, else prepare them
			for model in models
				if model instanceof Backbone.Model is false
					if not _.isObject model
						# must be id, check if a model with that id already exists, else add to idQueue
						if existModel = Backbone.JJStore._byId @.model.prototype.storeIdentifier, model
							model = existModel
						else
							idsToAdd.push model
							break
					else
						model = @._prepareModel model, options

				# check if models are instances of this collection's model
				if model
					if model instanceof @.model is false
						throw new TypeError 'Invalid model to be added to collection with relation key "' + @._relational.ownerKey + '"'
					else
						modelsToAdd.push model
						if model.id then idsToRemove.push model.id

			# handle idQueue
			@.removeFromIdQueue idsToRemove
			for id in idsToAdd
				@.addToIdQueue id

			# pass on relation if not silentRelation
			if not options.silentRelation
				for modelToAdd in modelsToAdd
					modelToAdd.addToRelation @._relational.owner, @._relational.reverseKey, true

			# set options.silentRelation to false for subsequent `set` - calls
			options.silentRelation = false

			# set options.merge to false as we have alread merged it with the call to `_prepareModel` above (when working with store)
			if Backbone.JJRelational.Config.work_with_store then options.merge = false
		
		# Normal "`add`" and return collection for chainability
		@.__set modelsToAdd, options

	###*
	 *
	 * @deprecated since Backbone v1.0.0, where `update` and `add` have been merged into `set`
	 * still present in Backbone.JJRelational v0.2.5
	 * 
	 * "`update`" has to be overridden,
	 * because in case of merging, we need to pass `silentRelation: true` to the options.
	 * 
	 * @param  {Object | Array | Backbone.Model} models         The models to add
	 * @param  {Object} options                                 Options object
	 * @return {Backbone.Collection}
	###
	###
	Backbone.Collection.update = (models, options) ->
		add = []
		remove = []
		merge = []
		modelMap = {}
		idAttr = @.model.prototype.idAttribute
		options = _.extend {add:true, merge:true, remove:true}, options

		if options.parse then models = @.parse models

		# Allow a single model (or no argument) to be passed.
		if not _.isArray models then (models = if models then [models] else [])

		# We iterate in every case, because of a different merge-handling

		# Determine which models to add and merge, and which to remove
		for model in models
			existing = @.get (model.id || model.cid || model[idAttr])
			if options.remove and existing then modelMap[existing.cid] = true
			if options.add and not existing then add.push model
			if options.merge and existing then merge.push model

		if options.remove
			for model in @.models
				if not modelMap[model.cid] then remove.push model

		# Remove models (if applicable) before we add and merge the rest
		if remove.length then @.remove(remove, options)
		# set options.merge to true for possible subsequent `add`-calls
		options.merge = true
		if add.length then @.add add, options
		if merge.length
			mergeOptions = _.extend {silentRelation:true}, options
			@.add merge, mergeOptions

		@
	###

	Backbone.Collection.prototype.__remove = Backbone.Collection.prototype.remove
	###*
	 * If this is a relational collection, the removal is passed on and the model is informed
	 * of the removal.
	 * 
	 * @param  {Backbone.Model} models                          The model to remove
	 * @param  {Object} options                                 Options object
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype.remove = (models, options) ->
		if not @._relational then return @.__remove models, options

		options || (options = {})
		if not _.isArray models
			models = [models]
		else
			models = models.slice()

		_.each models, (model) =>
				if model instanceof Backbone.Model is true
					@.__remove model, options
					if not options.silentRelation
						@._relatedModelRemoved model, options
		
		@

	###*
	 * Cleanup function for relational collections.
	 * 
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype._cleanup = ->
		@.remove @.models, {silentRelation:false}
		@._relational.idQueue = []
		@

	###*
	 * Informs the removed model of its removal from the collection, so that it can act accordingly.
	 * 
	 * @param  {Backbone.JJRelationalModel} model               The removed model
	 * @param  {Object} options                                 Options object
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype._relatedModelRemoved = (model, options) ->
		# invert silentRelation to prevent infinite looping
		if options.silentRelation then silent = false else silent = true
		model.removeFromRelation @._relational.reverseKey, @._relational.owner, silent
		@

	Backbone.Collection.prototype.__reset = Backbone.Collection.prototype.reset
	###*
	 * Cleans up a relational collection before resetting with the new ones.
	 * 
	 * @param  {Backbone.Model} models                          Models to reset with
	 * @param  {Object} options                                 Options object
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype.reset = (models, options) ->
		if @._relational then @._cleanup()
		@.__reset models, options
		@

	
	Backbone.Collection.prototype.__fetch = Backbone.Collection.prototype.fetch
	###*
	 * The fetch function...normal fetch is performed, after which the parsed response is checked if there are
	 * any models that already exist in the store (via id). If yes: the model will be updated, no matter what.
	 * After that, "`update`" or "`reset`" method is chosen.
	 * 
	 * @param  {Object} options                                Options object
	 * @return {Backbone.$.ajax}
	###
	Backbone.Collection.prototype.fetch = (options) ->
		options = if options then _.clone(options) else {}
		if options.parse is undefined then options.parse = true

		success = options.success
		options.success = (resp, status, xhr) =>
			# check if any of the fetched models have an id that already exists
			# if this is the case, merely update the existing model instead of creating a new one
			idAttribute = @.model.prototype.idAttribute
			storeIdentifier = @.model.prototype.storeIdentifier
			parsedResp = @.parse resp
			existingModels = []
			args = []
			args.push parsedResp
			for respObj in parsedResp
				id = respObj[idAttribute]
				existingModel = Backbone.JJStore._byId storeIdentifier, id
				if existingModel
					# this model exists. add it to existingModels[] and simply update the attributes as in 'fetch'
					existingModel.set respObj, options
					existingModels.push existingModel
					args.push respObj
			parsedResp = _.without.apply that, args

			# now that we've got everything together, check if to call 'reset' or 'update' and especially check if this is a relational collection
			# if yes, and 'reset', cleanup the whole collection, and ignore the owner model.
			if @._relational then options.ignoreModel = @._relational.owner
			models = existingModels.concat(parsedResp)
			method = if options.reset then 'reset' else 'set'
			# if update, set options.merge to false, as we've already merged the existing ones
			if not options.reset then options.merge = false

			@[method](models, options)

			if success then success(@, resp)
			@.trigger 'sync', @, resp, options

		wrapError @, options
		return @.sync.call(@, 'read', @, options)
	
	###*
	 * If any ids are stored in the collection's idQueue, the missing models will be fetched.
	 * 
	 * @param  {Object} options                                   Options object
	 * @return {Backbone.$.ajax}
	###
	Backbone.Collection.prototype.fetchByIdQueue = (options) ->
		if options then options = _.clone(options) else options = {}
		idQueue = @._relational.idQueue
		if idQueue.length > 0
			# set the url appropriately
			options.url = getUrlForIdQueue @, idQueue
			
			if options.parse is undefined then options.parse = true
			
			success = options.success
			options.success = (resp, status, xhr) =>
				# the owner model must be ignored by the fetched models when they're created and the relations are set
				options.ignoreModel = @._relational.owner
				# as we're fetching the rest which isn't present, we're always `add`-ing the model
				# and we have to empty the idQueue, otherwise we'll double add the models (by Backbone.JJStore.Events)
				@._relational.idQueue = []
				@.add(@.parse(resp), options)
				
				if success then success(@, resp)
				@.trigger 'sync', @, resp, options

			wrapError @, options
			return @.sync.call(@, 'read', @, options)
		@

	###*
	 * Adds an id to the collection's idQueue
	 * @param {mixed} id                                          The id to add
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype.addToIdQueue = (id) ->
		queue = @._relational.idQueue
		queue.push id
		@._relational.idQueue = _.uniq queue
		@

	###*
	 * Removes ids from the collection's idQueue
	 * @param  {mixed | Array} ids                                The (array of) id(s) to remove
	 * @return {Backbone.Collection}
	###
	Backbone.Collection.prototype.removeFromIdQueue = (ids) ->
		ids = if _.isArray then ids else [ids]
		args = [@._relational.idQueue].concat ids
		@._relational.idQueue = _.without.apply that, args
		@

	###*
	 * Returns an array of the collection's models' ids + idQueue
	 * @return {Array}
	###
	Backbone.Collection.prototype.getIDArray = ->
		ids = []
		@.each (model) ->
			if model.id then ids.push model.id
		_.union ids, @._relational.idQueue

	###*
	 * Returns an array of an attribute of all models.
	 * @param  {String} attr                                     The attribute's name
	 * @return {Array}
	###
	Backbone.Collection.prototype.getArrayForAttribute = (attr) ->
		if attr is @.model.prototype.idAttribute then return @.getIDArray()
		atts = []
		@.each (model) ->
			atts.push model.get(attr)
		atts


	# !-
	# !-
	# ! Helpers
	
	# Wrap an optional error callback with a fallback error event.
	# cloned from Backbone core
	wrapError = (model, options) ->
		error = options.error
		options.error = (resp) ->
			if error then error model, resp, options
			model.trigger 'error', model, resp, options

	###*
	 * Helper method that flattens relational collections within in an object to an array of models + idQueue.
	 * @param  {Object} obj     The object to flatten
	 * @return {Object}			The flattened object
	###
	flatten = (obj) ->
		for key, value of obj
			if (value instanceof Backbone.Collection) and value._relational then obj[key] = value.models.concat(value._relational.idQueue)
		obj 

	###*
	 * Helper method to get a value from an object. (functions will be called)
	 * @param  {Object} object
	 * @param  {String} prop
	 * @return {mixed}
	###
	getValue = (object, prop) ->
		if not (object and object[prop]) then return null
		if _.isFunction object[prop] then return object[prop]() else return object[prop]

	###*
	 * Helper method to get the url for a model (this is comparable to Backbone.Model.url)
	 * @param  {Backbone.Model} model
	 * @param  {mixed} id    (optional)
	 * @return {String}
	###
	getUrlForModelWithId = (model, id) ->
		base = getValue(model, 'urlRoot') || getValue(model.collection, 'url') || urlError()
		return base + (if base.charAt(base.length - 1) is '/' then '' else '/') + encodeURIComponent(if id then id else model.id)

	###*
	 * Helper method to get a formatted url based on an object and idQueue.
	 * @param  {Backbone.Model} obj
	 * @param  {Array} idQueue
	 * @return {String}
	###
	getUrlForIdQueue = (obj, idQueue) ->
		url = getValue obj, 'url'
		if not url
			urlError()
			return false
		else
			url += (Backbone.JJRelational.Config.url_id_appendix + idQueue.join(','))
			url

  	###*
  	 * Throw an error, when a URL is needed, but none is supplied.
  	 * @return {Error}
  	###
	urlError = ->
		throw new Error 'A "url" property or function must be specified'

	isOneType = (relation) ->
		if relation.type is 'has_one' then true else false

	isManyType = (relation) ->
		if (relation.type is 'has_many' or relation.type is 'many_many') then true else false


	@		
