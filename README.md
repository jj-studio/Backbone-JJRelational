 
```
__________                __   ___.                         
\______   \_____    ____ |  | _\_ |__   ____   ____   ____  
 |    |  _/\__  \ _/ ___\|  |/ /| __ \ /  _ \ /    \_/ __ \ 
 |    |   \ / __ \\  \___|    < | \_\ (  <_> )   |  \  ___/ 
 |______  /(____  /\___  >__|_ \|___  /\____/|___|  /\___  >
        \/      \/     \/     \/    \/            \/     \/ 
     ____.    ____.__________       .__          __  .__                     .__   
    |    |   |    |\______   \ ____ |  | _____ _/  |_|__| ____   ____ _____  |  |  
    |    |   |    | |       _// __ \|  | \__  \\   __\  |/  _ \ /    \\__  \ |  |  
/\__|    /\__|    | |    |   \  ___/|  |__/ __ \|  | |  (  <_> )   |  \/ __ \|  |__
\________\________| |____|_  /\___  >____(____  /__| |__|\____/|___|  (____  /____/
                           \/     \/          \/                    \/     \/      
```

### Version 0.2.6

__Backbone JJRelational__ is a plugin that provides __one-to-one, one-to-many, many-to-one and many-to-many__ bi-directional relations between Backbone models.  
  
Backbone JJRelational is inspired by [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational), but supports many-to-many relations out of the box.
  
Backbone JJRelational has been tested with Backbone 1.0.0 and Underscore 1.5.0

## Table Of Contents

- [Installation](#installation)
- [How to use](#how-to-use)
- [Setup example](#setup-example)
- [Getting and setting data](#getting-and-setting-data)
- [Sync - saving and fetching data](#saving-and-fetching-data)
- [Working with the store - prevent duplice data](#working-with-the-store)
- [The devil in the details](#devil-in-the-details)
- [Reference](#reference)
- [Running the tests](#running-the-tests)
- [License](#license)

<a name="installation" /> 
## Installation

Backbone JJRelational depends - who would have thought - on [Backbone.JS](https://github.com/documentcloud/backbone) and [Underscore.JS](https://github.com/documentcloud/underscore).  
Simply include backbone.JJRelational.js right after Underscore and Backbone.

```html
<script type="text/javascript" src="underscore.js"></script>
<script type="text/javascript" src="backbone.js"></script>
<script type="text/javascript" src="backbone.JJRelational.js"></script>
```

<a name="how-to-use" />
## How to use
When defining your models, simply extend from `Backbone.JJRelationalModel` instead of the regular `Backbone.Model` and define a property named `storeIdentifier` and a property named `relations`, which takes an array of objects containing your relational options. Each defined relational options object must at least contain `type`, `relatedModel`, `key` and `reverseKey`.  
For each specified relation, you must define the reverse relation on the other side. __This is very important__, if you want JJRelational to work properly.
Let's take a closer look at this.

### storeIdentifier

A string and mandatory. As each model registers itself in `Backbone.JJStore` upon creation, you have to define an identifier for a store, where instances of the model are put.  
Example:  
```javascript
Book = Backbone.JJRelationalModel.extend({
	storeIdentifier: 'Book'
});
```

###  Relational options

You can use the following options when defining `relations`.

#### type
_mandatory_  
A string that defines the type of the relation (from the model's point of view!).
Possible values are  
`has_one`: for __one-to-one__ or __many-to-one__ relations  
`has_many`: for __one-to-many__ relations  
`many_many`: for __many-to-many__ relations  

#### relatedModel
_mandatory_  
Same as in [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational), this is a string which can be resolved to an object type on the global scope, or a reference to a `Backbone.JJRelationalModel` type.
This - of course - defines which kind of model fills this relation.

#### key
_mandatory_  
A string naming the attribute under which the relation is stored.  
`has_one` relations are stored as a single `Backbone.JJRelationalModel`, or `null` when empty.  
`has_many` relations are stored as a `Backbone.Collection` or an extension of it - provided `collectionType` has been set and the collection type has been registered with `Backbone.JJRelational.registerCollectionTypes`.

#### reverseKey
_mandatory_  
A string naming the attribute of the related model's reverse relation. This is the same as `key` from the related model's point of view.  
For every relation you specify on a model, you __always__ have to specify a reverse relation on the related model in a fitting pattern. Remember: Each `key` is the same as `reverseKey` on the related side.  
Confused? Take a look at the [Setup example](#setup-example)

#### collectionType
A string referencing a collection type which has been registered with `Backbone.JJRelational.registerCollectionTypes()`. 
Explanation: If the relational attribute of a `has_many` or `many_many` relation should use one of your extensions of `Backbone.Collection`, you have to register the collection(s) with a key of your choice by using `Backbone.JJRelational.registerCollectionTypes()`, and then use that key within the relation's `collectionType` option.  
Example:  
```javascript```
BooksColl = Backbone.Collection.extend({
	model: Book
});

Backbone.JJRelational.registerCollectionTypes({
	'Books': BooksColl
	// …
	// … 
})
```
…and then within your relation options `collectionType: 'Books'`.

#### includeInJSON
This is an array of strings defining which attributes should be included when the model is saved.
Leaving `includeInJSON` empty means that merely the related model's `id` is included.

<a name="setup-example" />
## Setup example
Here is an example of how the relations between different models could be defined:

```javascript
/*
** Author
*/

// each author can have many books, and many publishers
Author = Backbone.JJRelationalModel.extend({
	storeIdentifier: 'Author',
	relations: [
		{
			type: 'has_many',
			relatedModel: 'Book',
			key: 'books',
			reverseKey: 'author',
			collectionType: 'Books',
			includeInJSON: ['id', 'title']
		},
		{
			type: 'many_many',
			relatedModel: 'Publisher',
			key: 'publishers',
			reverseKey: 'publishedAuthors',
			collectionType: 'Publishers'
		}
	]
});

AuthorsColl = Backbone.Collection.extend({
	model: Author
});

/*
** Book
*/

// each book has one author
Book = Backbone.JJRelationalModel.extend({
	storeIdentifier: 'Book',
	relations: [{
		type: 'has_one',
		relatedModel: 'Author',
		key: 'author',
		reverseKey: 'books',
		includeInJSON: ['id', 'firstname', 'surname']
	}]
});

BooksColl = Backbone.Collection.extend({
	model: Book
});

/*
** Publisher
*/

// each publisher has many authors
Publisher = Backbone.JJRelationalModel.extend({
	storeIdentifier: 'Publisher',
	relations: [{
		type: 'many_many',
		relatedModel: 'Author',
		key: 'publishedAuthors',
		reverseKey: 'publishers',
		collectionType: 'Authors'
	}]
});

PublishersColl = Backbone.Collection.extend({
	model: Publisher
});

// register collection types
Backbone.JJRelational.registerCollectionTypes({
	'Authors': AuthorsColl,
	'Books': BooksColl,
	'Publishers': PublishersColl
});

```
<a name="getting-and-setting-data" />
## Getting and setting data

As stated before, in a `has_one` relation, the model stores a single `Backbone.JJRelationalModel`. You get and set it in the usual Backbone fashion.  
  
```javascript
var whichBook = function (book) {
		var a = book.get('author');
		console.log('"' + book.get('title') + '" by ' + a.get('firstname') + ' ' + a.get('surname'));
	},
	twist = new Book({
		title: 'Oliver Twist',
		author: {
			firstname: 'Charles',
			surname: 'Dickens'
		}
	});
	
whichBook(twist); // <-- logs out '"Oliver Twist" by Charles Dickens
```

In `has_many` and `many_many` relations, the model stores an instance of `Backbone.Collection` (or an extension of it, if registered). Thus you should use collection methods on it.  
Tying to the lines of code above:  
```javascript
var carroll = new Author({ name: 'Lewis Carroll' }),
	penguin = new Publisher({
		name: 'Penguin Classics',
		publishedAuthors: [caroll, dickens]
	}),
	randomHouse = new Publisher({ name: 'Random House' });
	
randomHouse.get('publishedAuthors').add([carroll, dickens]);

carroll.get('publishers').each(function (publisher) {
	console.log(publisher.get('name')); // <-- logs out 'Penguin Classics' and 'Random House'
});

carroll.get('publishers').remove(randomHouse);

randomHouse.get('publishedAuthors').each(function (author) {
	console.log(author.get('firstname')); // <-- logs out 'Charles'
});
```

You also have the possibility to merely store `id`s within the relational attributes. These are automatically replaced with appropriate models, as soon as a model with one of these ids is created.
In a `has_one` relation, the id is directly stored under the `key`-attribute.  
In `has_many` and `many_many` relations, the relational collections have an own `id`-queue they juggle around with.
For clarification, check out the following lines of code:

```javascript
var theRoad = new Book({ title: 'The Road', author: 1 }),	cormac = new Author({ id: 1, firstname: 'Cormac', surname: 'McCarthy' });
whichBook(theRoad); // <-- logs out '"The Road" by Cormac McCarthy'
```

When the author model is created, it registers itself in the store and the book model gets notified of it - so it can replace the id with the real model.
Take a look at these two lines, which basically have the same effect:

```javascript
var cormac = new Author({ id: 1, firstname: 'Cormac', surname: 'McCarthy'}),
	theRoad = new Book({ title: 'The Road', author: 1 });
	
```

Although the author is created before the book, giving `author` an id (on the book model) triggers a lookup of the author.
Same same for `has_many` and `many_many` relations:

```javascript
var george = new Author({firstname: 'George', surname: 'Martin', books: [1]}),
	one = new Book({ id: 1, title: 'A Game Of Thrones' }),
	two = new Book({ id: 2, title: 'A Clash Of Kings' }),
	three = new Book({ id: 3, title: 'A Storm Of Swords' }),
	
	books = george.get('books');
	
	books.add([2, 3, {title: 'A Feast For Crows'}]).each(function (book) {
		whichBook(book);
	});
	
	// logs out all four books
```

__NOTE__: There is one thing that you should never do, and that is directly setting a collection on a relational attribute.
For example:
```javascript
var author = new Author({books: new BooksColl([{title: 'a book'}])}); // don't do that!
```
This will throw an error. Better use:
```javascript
var author = new Author({books: [{title: 'a book'}]}); // works fine!
```

<a name="saving-and-fetching-data" />
## Sync - saving and fetching data

### Saving

Backbone.JJRelational handles everything for you automatically. Nevertheless, this section should explain some of the concepts and possibilities you have when fetching from/persisting to the server.
When calling __save__ on a model, the `includeInJSON` property you defined for the relation is used to generate the JSON which gets persisted to the server. Going further, it is checked for you if a related model is new: If yes, the related model __gets saved before__! Confused? This example should make your head spin even more:

```javascript
// We pretend our relational setup is the same as in the setup example.
// So Publishers include publishedAuthors.id, Authors include books.id and books.title

var publisher = new Publisher({ name: "Faber & Faber", authors: [{ firstname: "Martin", surname: "McDonagh", books: [{ title: "The Pillowman" }] }] });
publisher.save();
```
Okay, now what's going to happen? Publisher relies on the author's id, author relies on the book's id. So at first a save request is fired for "The Pillowman":
```json
{
	"title": "The Pillowman"
}
```
Provided the book gets persisted to a database, for example, and gets an id, "Martin McDonagh"'s request is fired:
```json
{
	"firstname": "Martin"
	"surname": "McDonagh"
	"books": [{
		"id": 1,
		"title: "The Pillowman"
	}]
}
```
And now, at last, the publisher will be saved:
```json
{
	"name": "Faber & Faber"
	"authors": [1]
}
```
### Fetching

When fetching data from the server, Backbone.JJRelational automatically creates the needed models in a relation. Image we would call `fetch` on a collection of publishers and it would return:

```json
[
{
	"id": 1,
	"name": "Faber & Faber",
	"authors": [{
		"id": 1,
		"firstname": "Martin",
		"surname": "McDonagh"
	}]
}
]
```
The author model "Martin McDonagh" will be created automatically. Now let's pretend, fetching the publishers would result in merely an ID array of its authors:
```json
[
{
	"id": 1,
	"name": "Faber & Faber",
	"authors": [1,2]
},
{
	"id": 2,
	"name": "Random House",
	"authors": [3,4]
}
]
```
In this case, JJRelational doesn't create new author models, but stores the IDs in a queue within the relational collection. (`Backbone.Collection._relational.idQueue`)
If `faber` is our first publisher model, we can call

```javascript
faber.get('authors').fetchByIdQueue();
```

This will fetch the authors with IDs 1 and 2 and add them to the collection. (this works for one-to-one and one-to-many relations as well, of course)
Or, if we want to fetch _all related authors of the whole collection_, we can call: (pretending `pubColl` is our collection of publishers):

```javascript
pubColl.fetchByIdQueueOfModels('authors');
```

This will fetch the authors with IDs 1, 2, 3 & 4 and add them to their related publishers appropriately.

<a name="working-with-the-store" />
## Working with the store - prevent duplicate data

Backbone.JJStore acts as the big data store in your application which every newly created model registers itself at with its `id` and `storeIdentifier`. Each time a new model is created, all other models (which could be interested in a relationship to this new model) are informed of its creation. It's the same the other way round: Each time a mere ID is added to a relation, the store checks if there's already a model with the same id/storeIdentifier combination. If yes, the model from the store is used rather than the raw ID. 
Naturally, all this can work only if there are no duplicates present. 
This is what the configuration `Backbone.JJRelational.Config.work_with_store` (defaults to `true`) ensures.
In JJRelational, when you create a new model with an existing storeIdentifier/id combination, __the existing model with updated attributes will be returned__.
Let's clarify this with an example. 

```javascript
var a = new Author({ id: 1, firstname: "Jane", surname: "Doe" });
console.log("a: cid is %s and name is %s %s", a.cid, a.get('firstname'), a.get('surname'));

var b = new Author({ id: 1, surname: "Austen" });
console.log("b: cid is %s and name is %s %s", b.cid, b.get('firstname'), b.get('surname'));
```

In a regular Backbone application, this would output:
```
>  a: cid is c1 and name is Jane Doe
>  b: cid is c2 and name is undefined Austen
```

In JJRelational when `work_with_store` is set to `true`, the same logs would output: 
```
> a: cid is c1 and name is Jane Doe
> b: cid is c1 and name is Jane Austen
```

Smash. The store realizes there's already an author with the same ID, so it merely updates the existing one.

You can turn this behaviour off by setting `Backbone.JJRelational.Config.work_with_store` to `false`, however you should keep in mind that the synchronization of relations only works properly in __a duplicate-free environment__. 

<a name="devil-in-the-details" />
## The Devil in the details

The concept behind JJRelational is actually dirt-simple. On the creation of a model, it registers itself in `Backbone.JJStore`, and other models that could be interested in it are notified of the creation. Because relations are defined from both sides, it's easy to keep everything in sync.
Basically it's just juggling with models and attributes.

Some of Backbone methods had to be wrapped within some relational methods.	

---

<a name="reference" />
## Reference

### Backbone.JJRelational
#### `Config`
( _Object_ ) Global configuration object.
Possible values are:
- `url_id_appendix`: used for `fetchByIdQueue`- and `fetchByIdQueueOfModels`-calls. Default value is _'?ids='_ , the needed ids are then added comma separated. 
- `work_with_store`: Default is `true`. This option indicates whether you want Backbone.JJStore to prevent duplication of models. See [Working with the store](#working-with-the-store) for more information.

#### `registerCollectionTypes (collTypes<Object>)`
Registers one or many collection types, in order to build a correct collection instance for many-relations.

### Backbone.JJRelationalModel
#### `set (key<String|Object>, val<mixed|Object>, options<Object>)`
This is pretty much the most important override. Of course it does the same as Backbone core, although it filters relational values and handles them accordingly.  
Example:
```javascript
author.set({ publishers: [2, 3, publisherObj, { name: 'new publisher' }] });
```

#### `save (key<String|Object>, value<mixed|Object>, options<Object>)`
Backbone's original `save`-method wrapped in relational stuff. 
The concept is: When saving a model, it is checked whether it has any relations containing a new model. If yes, the new model is saved first. When all new models have been saved, only then is the calling model saved.  
Relational collections are saved as an array of models + idQueue.  
Concerning relations, the `includeInJSON` property is used for serializing to JSON.
See [Sync - saving and fetching data](#saving-and-fetching-data) for detailed information.

#### `_validate (attrs<Object>, options<Object>)`
The difference to Backbone core's `_validate` method is that this one flattens relational collections down to its model array. We've found that this is more convenient for more general validation functions.

#### `toJSON (options<Object>)`
If it's for saving ( `options.isSave == true ` ) then the `includeInJSON` option of the relation is used. That can go down as many levels as required.
If `isSave` is `false`, the related models are serialized regularly with their relations represented only by ids, however.

#### `toJSONWithRelIDs ()`
Returns a JSON of the model with all relations represented only by ids.

#### `fetchByIdQueue (relation<String|Object>, options<Object>)`
Fetches missing models of a relation, if their ids are known. See [Sync - saving and fetching data](#saving-and-fetching-data) for detailed information.

### Backbone.Collection

#### `fetchByIdQueue` (options<Object>)
If any IDs are stored in the collection's idQueue, this method will fetch the missing models.

#### `fetchByIdQueueOfModels (relation<String|Object>, options<Object>)`
Sums up `fetchByIdQueue`-calls on the same relation in a whole collection by collection the idQueues of each model and firing a single request. The fetched models are automatically added to their appropriate relations.

#### `getIDArray`
Returns an array of the collection's models' IDs + any IDs stored within the collection's idQueue (if present)


---
<a name="running-the-tests" />
## Running the tests

If you want to run the tests supplied, open up your terminal, change into the tests directory, run
```
$ npm update
```
once and then start the server with
```
$ node server.js
```

In your browser, navigate to [http://localhost:3000/tests.html](http://localhost:3000/tests.html). That's it.

---
<a name="license" />
## License

MIT
