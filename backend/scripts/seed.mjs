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
const products=[['organic-bananas','Organic Bananas','Produce'],['fresh-whole-milk','Fresh Whole Milk','Dairy & Eggs'],['eggs-grade-a','Eggs (Grade A)','Dairy & Eggs'],['white-sliced-bread','White Sliced Bread','Bakery'],['greek-yogurt','Greek Yogurt','Dairy & Eggs'],['fresh-red-apples','Fresh Red Apples','Produce']];
for(const [key,name,category] of products)put('catalogue/'+key,{name,category,active:true});
try {await batch.commit();console.log('Seeded demo household and six catalogue products locally. No Auth account created.');} finally {await deleteApp(app);}
