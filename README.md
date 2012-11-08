# Backbone JJRelational

## Version 0.1
---

Backbone JJRelational is a small plugin that allows __1-to-1__, __1-to-many__ and __many-to-many__ relations between models.
It is not only inspired by [Paul Uithol](https://github.com/PaulUithol)'s [Backbone-relational](https://github.com/PaulUithol/Backbone-relational); some ideas/lines of code have been directly taken from it.


## Table Of Contents
---
- [Installation](#installation)
- [Defining your relations](#defining-relations)

<a name="installation" />
## Installation
---
Backbone JJRelational depends  - who would have thought - on [Backbone](https://github.com/documentcloud/backbone) and [Underscore](https://github.com/documentcloud/underscore).
Simply include backbone.JJRelational.js (or the minified version) right after Underscore and Backbone.

```html
<script type="text/javascript" src="underscore.js"></script>
<script type="text/javascript" src="backbone.js"></script>
<script type="text/javascript" src="backbone.JJRelational.js"></script>
```

<a name="defining-relations" />
## Defining your relations
---
When defining your models, simply extend from `Backbone.JJRelationalModel` instead of the usual `Backbone.Model` and define a property named `relations`, which takes an array of objects containing your relational options.

### The example we will work with

```javascript
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

Book = Backbone.JJRelationalModel.extend({
	relations: [{
		type: 'has_one',
		relatedModel: 'Author',
		key: 'author',
		reverseKey: 'books'
	}]
});

Books = Backbone.Collection.extend({});

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
```










