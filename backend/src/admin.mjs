import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
export function localAdmin(name) {
 const projectId=process.env.GCLOUD_PROJECT||'demo-stage1';
 for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) {
  if(!/^127\.0\.0\.1:\d+$/.test(process.env[key]||''))throw Error(`${key} must identify a loopback emulator`);
 }
 if(projectId!=='demo-stage1')throw Error('Local backend requires demo-stage1');
 const app=initializeApp({projectId},name);
 return {app,db:getFirestore(app),auth:getAuth(app)};
}
