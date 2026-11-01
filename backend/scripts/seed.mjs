import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
const projectId=process.env.GCLOUD_PROJECT || 'demo-stage1';
if(projectId !== 'demo-stage1' || !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  throw new Error('Seed is restricted to demo-stage1 on a loopback Firestore emulator.');
}
const app=initializeApp({projectId});const db=getFirestore(app),batch=db.batch();
const now=Timestamp.now();
const put=(path,data)=>batch.set(db.doc(path),{schemaVersion:1,...data});
// Explicit demo IDs only; this never clears existing collections.
put('users/demo-owner',{displayName:'Demo owner',createdAt:now});
put('users/demo-owner/households/demo-household',{name:'Demo household'});
put('households/demo-household',{name:'Demo household',ownerUid:'demo-owner',createdAt:now,updatedAt:now,revision:1});
put('households/demo-household/members/demo-owner',{displayName:'Demo owner',role:'owner',status:'active',joinedAt:now});
put('households/demo-household/lists/demo-list',{name:'My Shopping List',archived:false,createdBy:'demo-owner',createdAt:now,updatedAt:now,revision:1});
put('households/demo-household/lists/demo-list/items/demo-milk',{productKey:'fresh-whole-milk',name:'Fresh Whole Milk',quantity:2,category:'Dairy & Eggs',unit:'items',notes:'',purchased:false,favourite:false,assigneeUid:null,deleted:false,createdBy:'demo-owner',createdAt:now,updatedAt:now,revision:1});
put('households/demo-household/safetyRules/fresh-whole-milk',{maximum:2,mode:'warn',updatedBy:'demo-owner',updatedAt:now,revision:1});
const slug = name => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

// mirrors guessCategory() in lib/wireframe/model.dart, with extra keywords for
// produce the Dart version misses (berries, mandarins, pumpkin, celery...).
const categoryFor = name => {
    const n = name.toLowerCase(), has = words => words.some(w => n.includes(w));
    if (has(['banana', 'apple', 'orange', 'grape', 'berry', 'berries', 'lemon', 'pear', 'peach', 'mango',
        'fruit', 'melon', 'mandarin', 'avocado', 'potato', 'carrot', 'onion', 'garlic', 'tomato',
        'lettuce', 'salad', 'broccoli', 'cauliflower', 'cabbage', 'spinach', 'cucumber', 'pumpkin',
        'zucchini', 'capsicum', 'mushroom', 'celery', 'corn', 'pea', 'bean', 'veg'])) return 'Produce';
    if (has(['milk', 'egg', 'cheese', 'yogurt', 'yoghurt', 'butter', 'cream', 'margarine'])) return 'Dairy & Eggs';
    if (has(['bread', 'bun', 'roll', 'cake', 'muffin', 'croissant', 'bagel', 'crumpet'])) return 'Bakery';
    if (has(['chicken', 'beef', 'lamb', 'pork', 'sausage', 'bacon', 'mince', 'steak', 'ham', 'fish',
        'salmon', 'prawn', 'meat'])) return 'Meat';
    if (has(['rice', 'pasta', 'noodle', 'cereal', 'oat', 'flour', 'sugar', 'salt', 'pepper', 'honey', 'jam',
        'vinegar', 'tea', 'coffee', 'tin', 'can', 'soup', 'sauce', 'oil', 'biscuit', 'cracker'])) return 'Pantry';
    return 'Other';
};

// where the keyword rules misfire. "Toilet Paper" contains "oil"; "Shampoo"
// contains "ham"; "Candles" contains "can"; "Hand Cream" contains "cream".
const overrides = {
    'orange-juice': 'Pantry', 'apple-juice': 'Pantry', 'lemonade': 'Pantry', 'water': 'Pantry',
    'tomato-sauce': 'Pantry', 'tinned-tomatoes': 'Pantry', 'tinned-fruit': 'Pantry',
    'peanut-butter': 'Pantry', 'baked-beans': 'Pantry', 'vegemite': 'Pantry',
    'chocolate': 'Pantry', 'hot-chocolate': 'Pantry', 'lollies': 'Pantry', 'chips': 'Pantry', 'nuts': 'Pantry',
    'hand-cream': 'Other', 'shaving-cream': 'Other', 'antiseptic-cream': 'Other',
    'toilet-paper': 'Other', 'shampoo': 'Other', 'candles': 'Other', 'potting-mix': 'Other',
};

const names = [
    'Apples', 'Bananas', 'Oranges', 'Mandarins', 'Grapes', 'Strawberries', 'Blueberries', 'Lemons',
    'Pears', 'Peaches', 'Mangoes', 'Watermelon', 'Pineapple', 'Avocado', 'Potatoes', 'Sweet Potatoes',
    'Carrots', 'Onions', 'Garlic', 'Tomatoes', 'Lettuce', 'Cucumber', 'Broccoli', 'Cauliflower',
    'Cabbage', 'Spinach', 'Pumpkin', 'Zucchini', 'Capsicum', 'Mushrooms', 'Celery', 'Corn', 'Peas', 'Beans',
    'Milk', 'Skim Milk', 'Soy Milk', 'Almond Milk', 'Cream', 'Sour Cream', 'Butter', 'Margarine', 'Cheese',
    'Cheddar Cheese', 'Cottage Cheese', 'Yoghurt', 'Eggs', 'Ice Cream',
    'Bread', 'Wholemeal Bread', 'Bread Rolls', 'Crumpets', 'English Muffins', 'Croissants', 'Cake',
    'Biscuits', 'Crackers', 'Cereal', 'Porridge Oats', 'Rice', 'Pasta', 'Noodles', 'Flour', 'Sugar', 'Salt',
    'Pepper', 'Honey', 'Jam', 'Vegemite', 'Peanut Butter', 'Olive Oil', 'Vegetable Oil', 'Vinegar',
    'Tomato Sauce', 'Pasta Sauce', 'Soup', 'Baked Beans', 'Tinned Tomatoes', 'Tinned Tuna', 'Tinned Fruit',
    'Chicken', 'Chicken Breast', 'Beef Mince', 'Steak', 'Lamb', 'Pork', 'Sausages', 'Bacon', 'Ham', 'Fish',
    'Salmon', 'Prawns', 'Tea Bags', 'Coffee', 'Hot Chocolate', 'Orange Juice', 'Apple Juice', 'Water',
    'Lemonade', 'Chocolate', 'Lollies', 'Chips', 'Nuts',
    'Toilet Paper', 'Tissues', 'Paper Towels', 'Dishwashing Liquid', 'Laundry Powder', 'Soap', 'Shampoo',
    'Conditioner', 'Toothpaste', 'Toothbrush', 'Deodorant', 'Razors', 'Bin Bags', 'Sponges', 'Batteries',
    'Light Bulbs', 'Paracetamol', 'Vitamins', 'Band-Aids', 'Cat Food', 'Dog Food', 'Shaving Cream',
    'Moisturiser', 'Hand Cream', 'Antiseptic Cream', 'Throat Lozenges', 'Denture Cleaner',
    'Cleaning Spray', 'Gloves', 'Aluminium Foil', 'Cling Wrap', 'Baking Paper', 'Sandwich Bags',
    'Candles', 'Matches', 'Pens', 'Notepad', 'Printer Paper', 'Envelopes', 'Stamps', 'Greeting Card',
    'Birthday Card', 'Birthday Present', 'Wrapping Paper', 'Sticky Tape', 'Scissors', 'Dog Treats',
    'Cat Litter', 'Plant Pots', 'Potting Mix',
];

for (const name of [...new Set(names)]) {
    const key = slug(name);
    const category = overrides[key] || categoryFor(name);
    console.log(key.padEnd(22), category);   
    put('catalogue/' + key, { name, category, active: true });
} 
try { await batch.commit(); console.log('Seeded demo household and `${names.length}` catalogue products. No Auth account created.');} finally {await deleteApp(app);}
