import {readFileSync} from 'node:fs';
const draft=JSON.parse(readFileSync(new URL('../hosting/.gowayki-generated.json',import.meta.url),'utf8'));
if(draft.status !== 'approved' || !draft.legal?.responsible || !draft.legal?.contactEmail || !draft.legal?.reviewed) {
  throw Error('Hosting contains unpublished legal drafts. Define the responsible party and contact, review the policies, then prepare an approved candidate before deployment.');
}
console.log('Hosting candidate approved for deployment.');
