# Backbone JJRelational

## Version 0.1


Backbone JJRelational is a side-product of the Backbone-Silverstripe-JJRestApi and a small plugin that allows __1-to-1__, __1-to-many__ and __many-to-many__ relations between models.
It is not only inspired by [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational); some ideas/lines of code have been directly taken from it.


## Table Of Contents

- [Installation](#installation)
- [Defining your relations](#defining-relations)
	- [The example we will work with](#our-example)
	- [The relations property](#relations-property)

<a name="installation" />
## Installation

Backbone JJRelational depends  - who would have thought - on [Backbone](https://github.com/documentcloud/backbone) and [Underscore](https://github.com/documentcloud/underscore).
Simply include backbone.JJRelational.js (or the minified version) right after Underscore and Backbone.

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

Authors = Backbone.Collection.extend({});

// each book has one author
Book = Backbone.JJRelationalModel.extend({
	relations: [{
		type: 'has_one',
		relatedModel: 'Author',
		key: 'author',
		reverseKey: 'books'
	}]
});

Books = Backbone.Collection.extend({});

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

Books = Backbone.Collection.extend({});

// register our collection types
Backbone.JJRelational.registerCollectionTypes({
	'Authors': Authors,
	'Books': Books,
	'Publishers': Publishers
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


