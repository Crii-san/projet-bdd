const dbTarget = db.getSiblingDB('ecommerce_reviews');

// Création d'un utilisateur applicatif dédié (pas super-admin)
dbTarget.createUser({
  user: 'app_mongo_user',
  pwd: 'app_mongo_password',
  roles: [
    { role: 'readWrite', db: 'ecommerce_reviews' }
  ]
});

// 2. Création de la collection reviews avec validation de schéma JSON
dbTarget.createCollection('reviews', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['product_id', 'user', 'rating', 'comment', 'created_at'],
      properties: {
        product_id: {
          bsonType: 'int',
          description: 'Référence au produit PostgreSQL'
        },
        user: {
          bsonType: 'object',
          required: ['user_id', 'name'],
          properties: {
            user_id: { bsonType: 'int' },
            name: { bsonType: 'string' }
          }
        },
        rating: {
          bsonType: 'int',
          minimum: 1,
          maximum: 5,
          description: 'Note de 1 à 5'
        },
        comment: { bsonType: 'string' },
        helpful_votes: { bsonType: 'int', minimum: 0 },
        created_at: { bsonType: 'date' }
      }
    }
  }
});

// 3. Création des index
// Index composé : optimise le tri par note pour un produit donné
dbTarget.reviews.createIndex({ product_id: 1, rating: -1 });

// Index textuel : permet la recherche de mots-clés dans les avis
dbTarget.reviews.createIndex({ comment: 'text' });

const sampleComments = [
  "Très bon produit, conforme à la description.",
  "Qualité moyenne, un peu déçu vu le prix.",
  "Excellent rapport qualité-prix, je recommande vivement !",
  "Livraison rapide mais emballage un peu abîmé.",
  "Parfait, correspond exactement à mes attentes.",
  "Ne fonctionne plus après deux jours d'utilisation.",
  "Très satisfait du service client et de l'article."
];

const batch = [];
for (let i = 1; i <= 3000; i++) {
  const productId = (i % 1000) + 1; // Lie aux 1000 produits de PostgreSQL
  const userId = (i % 500) + 1;

  batch.push({
    product_id: NumberInt(productId),
    user: {
      user_id: NumberInt(userId),
      name: `Client ${userId}`
    },
    rating: NumberInt(Math.floor(Math.random() * 5) + 1),
    comment: sampleComments[i % sampleComments.length],
    helpful_votes: NumberInt(Math.floor(Math.random() * 20)),
    created_at: new Date(Date.now() - Math.floor(Math.random() * 1000 * 60 * 60 * 24 * 60))
  });
}

dbTarget.reviews.insertMany(batch);