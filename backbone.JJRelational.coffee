do () ->
	"use strict"

	if typeof window is 'undefined'
		_ = require 'underscore'
		Backbone = require 'backbone' 
		exports = module.exports = Backbone
	else
		_ = window._
		Backbone = window.Backbone
		exports = window

	Backbone.JJRelational = {}
	Backbone.JJRelational.CollectionTypes = {}

	###
	 # 
	 # GENERAL FUNCTIONS
	 #
	###

	###
	 # Find a type on the global object by name. Splits name on dots (i.e. 'Store.Models.MyModel' will return exports['Store']['Models']['MyModel'])
	 # @param {String} name
	 # 
	###
	Backbone.JJRelational.getObjectByName = (name) ->
		type = _.reduce name.split('.'), (memo, val) ->
			memo[val]
		, exports

		if type isnt exports then return type else return null

	###
	 # registers a collection-type, in order to create a correct collection instance for many-relations
	 # @param {[Object]} collTypes
	 #  
	###
	Backbone.JJRelational.registerCollectionTypes = (collTypes) ->
		if not _.isObject(collTypes) then return

		for name, collection of collTypes
			Backbone.JJRelational.CollectionTypes[name] = collection
		true

	###
	 # gets a collection-type by the registered name
	 # if none is found, Backbone.Collection will be returned
	 # @param {String} name
	 #  
	###
	Backbone.JJRelational.getCollectionType = (name) ->
		for n, coll of Backbone.JJRelational.CollectionTypes
			if n is name then return coll

		return Backbone.Collection


	###
	 #
	 # the relational model extension of Backbone.Model
	 #  
	###
	Backbone.JJRelationalModel = Backbone.Model.extend

		###
	 	 # 
	 	 # Overwrite Backbone.Model.constructor
	 	 #  
		###
		constructor: (attributes, options) ->
			# build the Backbone Model normally
			Backbone.Model.apply( this, arguments )

			# set up the relational attributes
			@.prepopulate_rel_atts()
			# fill in with attributes
			@.populate_rels_with_atts(attributes)
			@

		###
		 #
		 # initializes the relational attributes. has_many and many_many get empty collections, has_one gets null,
		 #
		 #
		###
		prepopulate_rel_atts:  ->
			if @.relations
				for relation in @.relations
					# at first check if relatedModel is an instance of Backbone.JJRelationalModel or a string, in which case we should get it from the global scope
					relModel = relation.relatedModel
					if relModel is undefined or relModel.prototype instanceof Backbone.JJRelationalModel is false
						if _.isString(relModel)
							# try to get it from 'exports', our reference to window
							globalScopeObj = Backbone.JJRelational.getObjectByName relModel
							if globalScopeObj and globalScopeObj.prototype instanceof Backbone.JJRelationalModel is true
								relation.relatedModel = globalScopeObj
							else
								throw new TypeError 'relatedModel "' + relModel + '" is neither a reference to a JJRelationalModel nor a string referring to an object in the global scope'

					value
					if relation and relation.type isnt 'has_one' and collType = Backbone.JJRelational.getCollectionType relation.collectionType
						value = new collType()
						value._relational = 
							owner 		: @
							ownerKey 	: relation.key 
							reverseKey	: relation.reverseKey
						value.bind 'relational:remove', value._relatedModelRemoved
						value.bind 'relational:reset', value._cleanup
					else
						value = null
					@.attributes[relation.key] = value

					@.bind 'change:' + relation.key, @.relFieldChanged
				@.bind 'destroy', @._cleanupAllRelations
			@

		###
		 #
		 # fills in any relational values that have been passed in the constructor
		 # i.e. var m = new MyModel({ HasOneRelation : relationalModel });
		 # @param {Object} constructor_atts (@source Backbone.JJRelationalModel.constructor)
		 #
		###
		populate_rels_with_atts: (attributes) ->
			# function to check whether a value is instance of the related model or if a new model must be created
			checkAndAdd = (val, rel) =>
				if val instanceof relation.relatedModel is true
					@.addToRelation val, rel, false
				else if _.isObject(val) and val instanceof Backbone.Model is false
					newModel = new rel.relatedModel val
					@.addToRelation newModel, rel, false

			for key, value of attributes
				if relation = @.getRelationByKey key
					# check if the attribute is a whole collection and if that makes any sense
					if value instanceof Backbone.Collection is true
						throw new TypeError 'The attribute "' + key + '" is a collection. You should not replace whole collections in a relational attribute. Please use the direct reference to the model array (Backbone.Collection.models)'
					else
						value = if _.isArray value then value else [ value ]
						for v in value
							checkAndAdd v, relation
			@

		###
		 #
		 # general function when a relation field has changed
		 #
		###
		relFieldChanged: (model, attribute, options) ->
			# check if the relation was silently set (options.silentRelation)
			if options.silentRelation is true then return
			found = false
			for attrName, status of options.changes
				if found is false and status is true
					
					if (@.get(attrName) == attribute)
						found = true
						# get the relation and check if it is has_one, otherwise collections handle the rest
						relation = @.getRelationByKey attrName
						if relation
							@.trigger 'relational:change:' + relation.key
							if relation.type is 'has_one'
								# unbind previous relational:change: event
								@.unbind 'relational:change:' + relation.key
								if attribute instanceof relation.relatedModel is true
					
									@.setHasOneListeners relation.key, relation.reverseKey, attribute

									# pass on relation
									attribute.addToRelation @, relation.reverseKey, true
								else if attribute
									throw new TypeError 'Attribute "' + relation.key + '" is no instance of specified related model.'
							else if isManyType(relation)
								throw new Warning 'You have used \'set\' on the attribute of a many-relation. That\'s bad, man. Please use get("' + relation.key + '") and perform collection operations'

			false

		###
		 # functions for adding a model to a relation
		 # @param {Backbone.JJRelationalModel} model
		 # @param {String} relationKey
		 # @param {Boolean} silent 
		###
		addToRelation: (model, relation, silent) ->
			# if relation is not passed completely, it is treated as the key
			if not _.isObject relation then relation = @.getRelationByKey relation
			# console.log 'adding to relation ' + relation.key
			if relation and (model instanceof relation.relatedModel is true)
				# handling of has_one relation
				if isOneType(relation)
					@.set relation.key, model, {silentRelation: silent}
					@.setHasOneListeners relation.key, relation.reverseKey, model
				else if isManyType(relation)
					@.get(relation.key).add model, {silentRelation: silent}

			false

		removeFromRelation: (relation, model, silent) ->
			# if relation is not passed completely, it is treated as the key
			if not _.isObject relation then relation = @.getRelationByKey relation
			# console.log 'removing relation from ' + relation.key
			if relation
				if isOneType(relation)
					@.unbind 'relational:change:' + relation.key
					@.set relation.key, null, {silentRelation:silent}
				else if isManyType(relation)
					@.get(relation.key).remove model, {silentRelation:silent}
			@

		setHasOneListeners: (key, reverseKey, model) ->
			@.bind 'relational:change:' + key, ->
				model.removeFromRelation reverseKey, @, true
			@

		###
		 # cleanup function that removes all listeners and informs relations of removal
		###

		_cleanupAllRelations: ->
			# console.log 'cleaning up'
			for relation in @.relations
				# remove listeners
				@.unbind 'relational:change:' + relation.key
				@.unbind 'change:' + relation.key, @.relFieldChanged
				@.unbind 'destroy', @._cleanupAllRelations
				# inform relation of removal
				if isOneType(relation) and relModel = @.get(relation.key)
					@.set relation.key, null, false				
				if isManyType(relation)
					## console.log relation.key
					@.get(relation.key)._cleanup(false, true)
			@

		###
		 # @begin helper functions
		###

		getRelationByKey: (key) ->
			for relation in @.relations
				if relation.key is key then return relation
			false

		getRelationByReverseKey: (key) ->
			for relation in @.relations
				if relation.reverseKey is key then return relation
			false

		###
		 # @end helper functions
		###

	
	###
	 #
	 # Collection hacks
	 #
	###
	
	Backbone.Collection.prototype._add = Backbone.Collection.prototype.add
	Backbone.Collection.prototype.add = (models, options) ->
		# check if this collection belongs to a relation
		if not @._relational then return @._add models, options

		if @._relational
			# prepare options and models
			options || (options = {})
			if not _.isArray models
				models = [ models ] 

			modelsToAdd = []
			# check if models are instances of collection.model
			for model in models
				if model instanceof Backbone.Model is false
					model = @._prepareModel model
				if model instanceof @.model is false then throw new TypeError 'Invalid model to be added to collection with relation key "' + @._relational.ownerKey + '"' else modelsToAdd.push model


			if not options.silentRelation
				for modelToAdd in modelsToAdd
					# @todo: set fucking listeners
					@._setHasManyListeners modelToAdd

					# @todo: add the reverse relation to modelToAdd
					modelToAdd.addToRelation @._relational.owner, @._relational.reverseKey, true


		# return collection for chainability
		@._add modelsToAdd, options

	Backbone.Collection.prototype.__remove = Backbone.Collection.prototype.remove
	Backbone.Collection.prototype.remove = (models, options) ->
		options || (options = {})
		if not _.isArray models
			models = [models]
		else
			models = models.slice 0

		_.each models, (model) =>
				if model instanceof Backbone.Model is true
					@.__remove model, options
					if not options.silentRelation
						@.trigger 'relational:remove', model, options
		
		@

	Backbone.Collection.prototype._cleanup = (call_remove, unbind) ->
		##
		## IMPORTANT: Backbone core usually handles the removal from every collection the model appears in
		##

		#@.remove @.models, {silentRelation:false}
		if call_remove
			@.remove @.models, {silentRelation:false}
		if unbind
			@.unbind 'relational:remove'
			@.unbind 'relational:reset'
		@

	Backbone.Collection.prototype._relatedModelRemoved = (model, options) ->
		# invert silentRelation to prevent infinite looping
		if options.silentRelation then silent = false else silent = true
		model.removeFromRelation @._relational.reverseKey, @._relational.owner, silent
		@

	Backbone.Collection.prototype._setHasManyListeners = (model) ->
		# console.log 'setting has many listeners'
		@

	Backbone.Collection.prototype.__reset = Backbone.Collection.prototype.reset
	Backbone.Collection.prototype.reset = (models, options) ->
		@.trigger 'relational:reset', true, false
		@.__reset models, options
		@

	isOneType = (relation) ->
		if relation.type is 'has_one' then true else false

	isManyType = (relation) ->
		if (relation.type is 'has_many' or relation.type is 'many_many') then true else false

	@


			
