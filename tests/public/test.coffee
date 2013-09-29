should = chai.should()
expect = chai.expect
assert = chai.assert

# make relations

it 'BackboneJJRelational should be present', ->
	should.exist Backbone.JJRelational

A = Backbone.JJRelationalModel.extend
	storeIdentifier: 'A'
	relations: [
		{
			type: 'many_many'
			relatedModel: 'B',
			key: 'bs',
			reverseKey: 'as'
		}
	]

B = Backbone.JJRelationalModel.extend
	storeIdentifier: 'B'
	relations: [
		{
			type: 'many_many'
			relatedModel: 'A',
			key: 'as',
			reverseKey: 'bs'
		}
	]

##

Author = Backbone.JJRelationalModel.extend
	storeIdentifier: 'Author'
	urlRoot: 'api/Author'
	relations: [
		{
			type: 'has_one',
			relatedModel: 'Wife',
			key: 'wife',
			reverseKey: 'husband',
			includeInJSON: ['id']
		},
		{
			type: 'has_many',
			relatedModel: 'Book',
			collectionType: 'Books',
			key: 'books',
			reverseKey: 'author',
			includeInJSON: ['id']
		},
		{
			type: 'many_many',
			relatedModel: 'Publisher',
			collectionType: 'Publishers'
			key: 'publishers',
			reverseKey: 'authors',
			includeInJSON: ['id']
		}
	]

Wife = Backbone.JJRelationalModel.extend
	storeIdentifier: 'Wife'
	relations: [
		{
			type: 'has_one',
			relatedModel: 'Author',
			key: 'husband',
			reverseKey: 'wife',
			includeInJSON: ['id']
		}
	]

Book = Backbone.JJRelationalModel.extend
	storeIdentifier: 'Book'
	urlRoot: 'api/Book'
	relations: [
		{
			type: 'has_one',
			relatedModel: 'Author',
			key: 'author',
			reverseKey: 'books',
			includeInJSON: ['id']	
		}
	]

Publisher = Backbone.JJRelationalModel.extend
	storeIdentifier: 'Publisher'
	relations: [
		{
			type: 'many_many',
			relatedModel: 'Author',
			collectionType: 'Authors',
			key: 'authors',
			reverseKey: 'publishers',
			includeInJSON: ['id']
		}
	]

AuthorsColl 	= Backbone.Collection.extend
	model: Author
	url: 'api/Author'

BooksColl 		= Backbone.Collection.extend
	model: Book
	url: 'api/Book'

PublishersColl 	= Backbone.Collection.extend
	model: Publisher
	url: 'api/Publisher'

Backbone.JJRelational.registerCollectionTypes
	'Books': BooksColl
	'Publishers': PublishersColl
	'Authors': AuthorsColl

# -

describe 'Backbone JJStore', ->
	b = new Book { title: 'Harry Potter', id: 999 }
	a = new A {id: 'foobar'}
	it 'should find Harry Potter _byId', ->
		Backbone.JJStore._byId('Book', b.id).get('title').should.equal 'Harry Potter'
	it 'should remove model from store without problems', ->
		console.log Backbone.JJStore._byId('A', 'foobar')
		Backbone.JJStore.__removeModelFromStore a
		should.not.exist Backbone.JJStore._byId('A', 'foobar')

describe 'New author', ->
	a = new Author()

	it 'should have property `wife`', ->
		a.attributes.should.have.property 'wife', null
	it 'should have instance of BooksColl as attribute `books`', ->
		a.attributes.books.should.be.an.instanceof BooksColl
	it 'should have instance of PublishersColl as attribute `publishers`', ->
		a.attributes.publishers.should.be.an.instanceof PublishersColl

describe 'Testing setting/adding/removing from relations', ->
	orwell = new Author {name: 'George Orwell' }
	describe 'HasOne Relation', ->
		eileen = new Wife { name: 'Eileen' }
		orwell.set { wife: eileen }

		it 'Adding Eileen to Orwell: Eileen should have George Orwell as husband', ->
			eileen.get('husband').get('name').should.equal 'George Orwell'
		it 'Removing Orwell from Eileen: Orwell\'s wife should be null', ->
			eileen.set { husband: null }
			orwell.attributes.should.have.property 'wife', null
		it 'Adding a wife ID to Orwell should sync', ->
			w = new Wife { name: 'Some random hoe', id: 1000 }
			orwell.set {wife: 1000}
			orwell.get('wife').get('name').should.equal 'Some random hoe'


	describe 'HasManyRelation', ->
		book1984 = new Book { title: '1984' }
		orwell.get('books').add book1984

		it 'Adding 194 to Orwell: 1984 should have George Orwell as author', ->
			book1984.get('author').should.equal orwell
		it 'Removing Orwell from 1984: Orwell should have no books', ->
			book1984.set({author: null})
			orwell.get('books').length.should.equal 0
		it 'Adding book ID to Orwell should sync', ->
			randomBook = new Book { name: 'Book he never wrote', id: 1000 }
			orwell.get('books').add(1000)
			randomBook.get('author').should.equal orwell

	describe 'ManyManyRelation', ->
		orwell.get('publishers').add [{ name: 'Random House' }, { name: 'Heine Hardcore' }]
		it 'Orwells publishers should also have him as author', ->
			ok = true
			orwell.get('publishers').each (publisher) ->
				if not publisher.get('authors').findWhere({ name: 'George Orwell' }) then ok = false
			ok.should.equal true
		it 'Removing orwell from one of his publishers should leave him with only one publisher', ->
			pub = orwell.get('publishers').models[0]
			pub.get('authors').remove orwell
			orwell.get('publishers').length.should.equal(1)

		it 'Resetting relational collection should sync', ->
			pub = orwell.get('publishers').models[0]
			pub.get('authors').reset({ name: 'J.K. Rowling' })
			orwell.get('publishers').length.should.equal(0)

		it 'Adding publisher ID to Orwell should sync', ->
			randomPublisher = new Publisher { name: 'PubSub', id: 1000 }
			orwell.get('publishers').add(1000)
			randomPublisher.get('authors').models[0].should.equal orwell


describe 'Deep relations (almost true love) and smart update', ->
	windsOfWinter = new Book { title: 'Winds of winter', id: 20 }
	feast = new Book { title: 'A feast for crows', id: 21 }
	harper = null

	it 'Martin should have relations to books with ids 20, 21, 22', ->
		harper = new Publisher { name: 'HarperVoyager', id: 20, authors: [{ id: 20, name: 'Martin', books: [ 20, feast, { title: 'Storm of swords', id: 22 }] }] }
		martin = harper.get('authors').get 20

		martin.get('books').length.should.equal 3
		for id in [20,21,22]
			book = martin.get('books').get(id)
			book.get('author').should.equal martin
		


	it 'Model should be the same, but name should have changed', ->
		martin = harper.get('authors').get 20
	
		harper.get('authors').add { id: 20, name: 'George R.R.Martin' }
		harper.get('authors').get(20).cid.should.equal martin.cid
		harper.get('authors').get(20).get('name').should.equal 'George R.R.Martin'

	it 'Martin should have relations to books with ids 20, 22, 23, 24 and 25 in idQueue', ->
		clash = new Book { id: 23, title: 'Clash of Kings' }
		game = new Book { id: 24, title: 'Game of thrones' }
		martin = harper.get('authors').get 20
		martin.get('books').set [{id: 20, title: "The winds of winter" }, 23, game, 22, 25]

		martin.get('books').length.should.equal 4
		for id in [20, 22,23,24]
			book = martin.get('books').get id
			book.get('author').should.equal martin

		martin.get('books')._relational.idQueue[0].should.equal 25

	it 'windsofWinter\'s title should have changed', ->
		windsOfWinter.get('title').should.equal 'The winds of winter'
		

describe 'Validation', ->
	a = new Author { id: 50, name: 'Foo author' }
	a.validate = (attrs, options) ->
		if attrs.wife.name isnt 'Bar wife' then return true
		false
	it 'validation should fail I', ->
		(a.set 'wife', {name: 'Your momma'}, {validate: true}).should.equal false

	it '_prepareModel should return false => no relation to set', ->
		p = new Publisher {name: 'foobario'}
		p.get('authors').add([{ id: 50, wife: {name: 'Your momma'}}], {validate: true})
		b = p.get('authors').get(50)
		should.not.exist b
		should.not.exist a.get('wife')




describe 'Saving', ->
	fontane = new Author { name: 'Theodor Fontane' }

	it 'Should save new book and sync it correctly', (done) ->
		irrungen = new Book { title: 'Irrungen und Wirrungen' }
		fontane.get('books').add irrungen
		fontane.save null,
			success: ->
				if irrungen.id and irrungen.get('author').id is fontane.id then done()

describe 'Fetching', ->
	authColl = new AuthorsColl()
	before (done) ->
		authColl.fetch
			success: ->
				done()

	it 'should successfully `fetchByIdQueueOfModels` related books', (done) ->
		bookCount = 0
		authColl.fetchByIdQueueOfModels 'books',
			success: ->
				done()


