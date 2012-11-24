# Backbone JJRelational

## Version 0.1


Backbone JJRelational is a small plugin that allows __1-to-1__, __1-to-many__ and __many-to-many__ relations between models.
It is not only inspired by [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational); some ideas/lines of code have been directly taken from it.


## Table Of Contents

- [Installation](#installation)
- [Defining your relations](#defining-relations)
	- [The example we will work with](#our-example)
	- [The relations property](#the-relations-property)
	- [The importance of reverse relations](#the-importance-of-reverse-relations)
- [Getting and setting your data](#getting-and-setting-your-data)
- [About collections](#about-collections)
	- [Registering collections](#registering-collections)
	- [Limitations](#limitations)
- [The Devil in the details](#the-devil-in-the-details)
	- [Yet missing](#yet-missing)

<a name="installation" />
## Installation

Backbone JJRelational depends  - who would have thought - on [Backbone](https://github.com/documentcloud/backbone) and [Underscore](https://github.com/documentcloud/underscore).
Simply include backbone.JJRelational.js right after Underscore and Backbone.

```html
<script type="text/javascript" src="underscore.js"></script>
<script type="text/javascript" src="backbone.js"></script>
<script type="text/javascript" src="backbone.JJRelational.js"></script>
```


<a name="defining-relations" />
## Defining your relations

When defining your models, simply extend from `Backbone.JJRelationalModel` instead of the usual `Backbone.Model` and define a property named `relations`, which takes an array of objects containing your relational options.

<a name="our-example" />
### The example we will work with


```javascript

// each author can have many books, and many publishers
Author = Backbone.JJRelationalModel.extend({
	relations: [
		{
			type: 'has_many',
			relatedModel: 'Book',
			key: 'books',
			reverseKey: 'author',
			collectionType: 'Books'
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

// each book has one author
Book = Backbone.JJRelationalModel.extend({
	relations: [{
		type: 'has_one',
		relatedModel: 'Author',
		key: 'author',
		reverseKey: 'books'
	}]
});

BooksColl = Backbone.Collection.extend({
	model: Book
});

// each publisher has many authors
Publisher = Backbone.JJRelationalModel.extend({
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

// register our collection types
Backbone.JJRelational.registerCollectionTypes({
	'Authors': AuthorsColl,
	'Books': BooksColl,
	'Publishers': PublishersColl
});


```

<a name="relations-property	" />
### The relations property

Let's take a closer look at the relations property: Each options object takes `type`, `relatedModel`, `key`, `reverseKey` and `collectionType` as arguments.

#### key
A string naming the attribute on which the relation can be accessed. (in the example above you would get the books of an author by calling `anAuthor.get('books');`).

#### relatedModel
Same as in [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational), this is a string which can be resolved to an object type on the global scope, or a reference to a `Backbone.JJRelationalModel` type.

Check this:

```javascript
Author = Backbone.JJRelationalModel.extend({ // using 'var Author' would work in this case
	relations: [{
			type: 'has_many',
			relatedModel: Book,		// this won't work, but using the string 'Book' will
			key: 'books',
			reverseKey: 'author',
			collectionType: 'Books'
	}]
});

Book = Backbone.JJRelationalModel.extend({ // using 'var Book' wouldn't work in this case
	relations: [{
		type: 'has_one',
		relatedModel: Author, // this works, but using the string 'Author' would work as well
		key: 'author',
		reverseKey: 'books'
	}]
});
```


#### type
A string which can be:

* ##### has_one
	for __one-to-one__ or __many-to-one__ relations. In our example, each book can have one author => has_one   
	Under the `key`-attribute, the model stores a single `Backbone.JJRelationalModel`, or `null` when empty.
	
	
* ##### has_many
	for __one-to-many__ relations. In our example, each author can have many books => has_many  
	Under the `key`-attribute, the model stores a `Backbone.Collection` or an extension of it - provided `collectionType` has been set and the collection type has been registered with `Backbone.JJRelational.registerCollectionTypes()`. Read more at [About Collections](#about-collections)
	
* ##### many_many
	for __many-to-many__ relations. In our example, each author can have many publishers and each publisher can have many authors => many_many  
	Same as in _has_many_: Under the `key`-attribute, the model stores a `Backbone.Collection` or an extension of it - provided `collectionType` has been set and the collection type has been registered with `Backbone.JJRelational.registerCollectionTypes()`. Read more at [About Collections](#about-collections)
	
#### reverseKey
A string naming the attribute of the related model's reverse relation.
Read more at [The importance of reverse relations](#the-importance-of-reverse-relations)

#### collectionType
A string referencing a collection type which has been registered with `Backbone.JJRelational.registerCollectionTypes()`. Read more at [About Collections](#about-collections)

<a name="the-importance-of-reverse-relations" />
### The importance of reverse relations

For every relation you specify on a model, please bear in mind that you __always__ have to specify a reverse relation on the related model in a fitting pattern.
In our example's relation between `Author` and `Book`, the relation on the _Author_-side looks like:

```javascript
{
	type: 'has_many',
	relatedModel: 'Book',
	key: 'books',
	reverseKey: 'author',
	collectionType: 'Books'
}
```

and on the _Book_-side

```javascript
{
	type: 'has_one',
	relatedModel: 'Author',
	key: 'author',
	reverseKey: 'books'
}
```

Each `key` property is the same as the `reverseKey` on the related side.
__This is utterly important, otherwise related models won't know what to do when faced with changes!__

<a name="getting-and-setting-your-data" />
## Getting and setting your data

As stated before, in a `has_one` relation, the model stores a single `Backbone.JJRelationalModel`.
You get and set it in the usual Backbone fashion.

```javascript
var whichBook = function (book) {
		var a = book.get('author');
		console.log('"' + book.get('title') + '" by ' + (a ? a.get('name') : 'unknown'));
	},
	dickens = new Author({ name: 'Charles Dickens' }),
	twist = new Book({ title: 'Oliver Twist', author: dickens});

whichBook(twist); // <-- logs out '"Oliver Twist" by Charles Dickens'
```

In `has_many` and `many_many` relations, the model stores a `Backbone.Collection` (or an extension of it, if registered). Thus you should use collection-methods on it (by now).
Tying to the lines of code above:

```javascript
var carroll = new Author({ name: 'Lewis Caroll' }),
	penguin = new Publisher({ name: 'Penguin Classics', publishedAuthors: [carroll, dickens] }),
	randomHouse = new Publisher({ name: 'Random House' });
	
randomHouse.get('publishedAuthors').add([carroll, dickens]);

carroll.get('publishers').each(function (publisher) {
	console.log(publisher.get('name')); // <-- logs out 'Penguin Classics' and then 'Random House'
});

carroll.get('publishers').remove(randomHouse);

randomHouse.get('publishedAuthors').each(function (author) {
	console.log(author.get('name')); // <-- logs out 'Charles Dickens'
});

```


<a name="about-collections" />
## About collections

<a name="registering-collections" />
### Registering collections

If the relational attribute of a `has_many` or `many_many` relation should use one of your extensions of `Backbone.Collection`, there are two steps you have to do.
Firstly, register the collection(s) with a key of your choice by using `Backbone.JJRelational.registerCollectionTypes()`. This should happen after you've defined your collection.

```javascript
PublishersColl = Backbone.Collection.extend({
	model: Publisher
});

Backbone.JJRelational.registerCollectionTypes({
	'Publishers': PublishersColl
});

AuthorsColl = Backbone.Collection.extend({
	model: Author,
	sayHello: function () {
		console.log('Hi, I am an author collection');
	}
});

Backbone.JJRelational.registerCollectionTypes({
	'Authors': AuthorsColl
});
```

Of course you can also combine them

```javascript
Backbone.JJRelational.registerCollectionTypes({
	'Publishers': PublishersColl,
	'Authors': AuthorsColl
});
```

Secondly, add the key for your collectionType to your relation options object, for example `collectionType: 'Authors'`.

```javascript
penguin.get('publishedAuthors').sayHello();
```

<a name="limitations" />
### Limitations
 
There are some things that will not work (yet). For example, when working with `has_many` or `many_many` relations, you shouldn't call `set` on your relational attribute or replace the relational collection with another.
To clarify:
- - -
This will work
```javascript
var penguin = new Publisher({ title: 'Penguin Classics', publishedAuthors: [dickens, carroll] });
```

This will __NOT__ work
```javascript
var penguin = new Publisher({ title: 'Penguin Classics', publishedAuthors: new AuthorsColl([dickens, carroll]) });
```
- - -
This will work
```javascript
var authors = penguin.get('publishedAuthors');
authors.add([dickens, carroll]);
```

This will __NOT__ work
```javascript
var authors = new AuthorsColl([dickens, carroll]);
penguin.set('publishedAuthors', authors);
```
- - -

On relational collections, use collection methods like `add`, `reset`, `remove` etc.

<a name="the-devil-in-the-details" />
## The Devil in the details

The concept behind JJRelational is actually dirt-simple. On the creation of a model, a `change` and a `destroy` event listener is bound to it. Furthermore - if the relation type is `has_many` or `many_many` - the relational attribute is populated with a collection of the collectionType (or `Backbone.Collection`), adding to the collection a `_relational` property which is an object that takes an `owner` (the model the collection 'belongs to'), an `ownerKey` (same as `relation.key`) and `reverseKey` (same as `relation.reverseKey`).
`Backbone.Collection.prototype.add`, `Backbone.Collection.prototype.remove` and `Backbone.Collection.prototype.reset` methods are also hacked into, checking if there are any relations and passing on the models accordingly.
Basically it's just pushing models around, no magic involved.

<a name="yet-missing" />
### Yet missing

There is no implementation of what [Paul Uithol](https://github.com/PaulUithol) is doing with [includeInJSON](https://github.com/PaulUithol/Backbone-relational#includeinjson) yet. But this will be added in the near future.

UPDATE: Backone JJRelational is part of another project. As that project grows, so does JJRelational. There'll be some major changes in the near future.



