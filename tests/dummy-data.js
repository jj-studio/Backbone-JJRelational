module.exports = {

	"Author": [
		{
			id: 1,
			name: "Charles Dickens",
			wife: 1,
			books: [5,6],
			publishers: [1,2]
		},
		{
			id: 2,
			name: "Johann Wolfgang von Goethe",
			wife: 2,
			books: [3,4],
			publishers: [1]
		},
		{
			id: 3,
			name: "Lewis Carroll",
			books: [1],
			publishers: [1,2]
		}
	],

	"Wife": [
		{
			id: 1,
			name: "Catherine Dickens",
			husband: 1
		},
		{
			id: 2,
			name: "Christiane von Goethe",
			husband: 2
		}
	],

	"Book": [
		{
			id: 1,
			title: "Alice In Wonderland",
			author: 3
		},
		{
			id: 2,
			title: "Faust - der Tragödie erster Teil",
			author: 2
		},
		{
			id: 3,
			title: "Faust - der Tragödie zweiter Teil",
			author: 2
		},
		{
			id: 4,
			title: "Die Leiden des jungen Werther",
			author: 2
		},
		{
			id: 5,
			title: "Oliver Twist",
			author: 1
		},
		{
			id: 6,
			title: "Barnaby Rudge",
			author: 1
		}
	],

	"Publisher": [
		{
			id: 1,
			name: "Reclam Verlag",
			authors: [1,2,3]
		},
		{
			id: 2,
			name: "Penguin Books",
			authors: [3,1]
		}
	]

};