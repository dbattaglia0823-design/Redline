import fs from 'node:fs';
import { validateIntegration } from './toolkit_validation/validator.js';

// Offline toolkit contract gate. Host callbacks own every gameplay mutation.
const handlerIds=['garage.previous','garage.next','nav.upgrades','nav.customize','garage.change_vehicle','dealership.search','dealership.filter','dealership.select','dealership.purchase_request','nav.dealership_classes','dealership.previous','dealership.next','dealership.details','dealership.equip_on_purchase'];
const example={garage:{balance:'$2400',selected:{display_name:'Mazda MX-5 Miata',name:'Mazda MX-5 Miata',subtitle:'1990 Mazda · Engine class E',summary:'RWD / 5-speed Manual',stats:[{label:'POWER',value:'116 hp'}]}},dealership:{balance:'$2400',search:'',vehicles:[{id:'miata',name:'Mazda MX-5 Miata'}],selected:{display_name:'Mazda MX-5 Miata',name:'Mazda MX-5 Miata',subtitle:'1990 Mazda · RWD / 5-speed Manual',price:'Equipped',stats:[{label:'POWER',value:'116 hp'}]}}};
const input=[...['garage','dealership'].map(key=>({file:'assets/ui/toolkit/'+key+'.layout.json',layout:JSON.parse(fs.readFileSync('assets/ui/toolkit/'+key+'.layout.json','utf8')),sampleData:example}))];
const snapshots=process.argv[2]??'.qa/toolkit-ui/contracts';
if(fs.existsSync(snapshots)) for(const file of fs.readdirSync(snapshots).filter(x=>x.endsWith('.json'))) input.push({file:snapshots+'/'+file,...JSON.parse(fs.readFileSync(snapshots+'/'+file,'utf8'))});
const reports=input.map(({file,layout,sampleData})=>{
 const report=validateIntegration(layout,{handlerIds,sampleData});
 const unexpected=report.warnings.filter(issue=>!((issue.code==='UNBOUND_DATA'&&issue.nodeId==='heading')||(issue.code==='UNMAPPED_ACTION'&&issue.nodeId==='vehicle_stats')));
 return {file,valid:report.valid&&unexpected.length===0,errors:report.errors,unexpected,documentedWarnings:report.warnings.filter(x=>!unexpected.includes(x))};
});
fs.mkdirSync('.qa/toolkit-ui',{recursive:true});
fs.writeFileSync('.qa/toolkit-ui/contract_validation.json',JSON.stringify(reports,null,2)+'\n');
for(const report of reports) console.log(report.valid?'PASS':'FAIL',report.file,report.unexpected);
if(reports.some(x=>!x.valid)) process.exitCode=1;
