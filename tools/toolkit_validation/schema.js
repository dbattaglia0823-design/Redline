/** UI Layout Contract v2: geometry + semantic roles + actions + data bindings only. */
export const VERSION = 2;
export const NODE_TYPES = Object.freeze(['panel','label','button','grid','list','slot','progress','toggle','slider','input']);
const DEFAULT_SIZE = Object.freeze({
 panel:[270,180],label:[240,44],button:[180,54],grid:[340,245],list:[300,240],
 slot:[90,85],progress:[240,24],toggle:[190,48],slider:[230,42],input:[230,48]
});
const ACTION_TYPES=new Set(['button','grid','list','slot','toggle','slider','input']);
const BINDING_TYPES=new Set(['label','grid','list','slot','progress','toggle','slider','input']);
const token=/^[A-Za-z][A-Za-z0-9_.-]{0,79}$/;
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const text=(x,max=100)=>String(x??'').slice(0,max);
const cleanToken=(x)=>x==null||x===''?'':token.test(x)?x:'';
const num=(x,d,min,max)=>typeof x==='number'&&Number.isFinite(x)?clamp(Math.round(x),min,max):d;

export function normalizeNode(raw,index=0) {
 if(!raw||typeof raw!=='object'||!NODE_TYPES.includes(raw.type)) throw new TypeError('Invalid UI node type');
 const [w,h]=DEFAULT_SIZE[raw.type],id=cleanToken(raw.id)||'node_'+(index+1);
 return {
  id,type:raw.type,x:num(raw.x,30,0,4000),y:num(raw.y,30,0,4000),
  w:num(raw.w,w,24,4000),h:num(raw.h,h,16,4000),
  label:text(raw.label,100),role:cleanToken(raw.role),
  actionId:ACTION_TYPES.has(raw.type)?cleanToken(raw.actionId):'',
  bindingKey:BINDING_TYPES.has(raw.type)?cleanToken(raw.bindingKey):''
 };
}
export function normalizeLayout(raw) {
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new TypeError('Invalid layout');
 if(raw.version!==VERSION)throw new Error('Unsupported layout version: expected 2');
 if(!Array.isArray(raw.nodes)||raw.nodes.length>120)throw new RangeError('Invalid node count');
 const viewport={
  width:num(raw.viewport?.width,800,320,4000),height:num(raw.viewport?.height,500,240,4000)
 };
 const nodes=raw.nodes.map(normalizeNode),ids=new Set();
 for(const node of nodes){
  if(ids.has(node.id))throw new Error('Duplicate node ID: '+node.id);
  ids.add(node.id);
 }
 return {version:VERSION,name:text(raw.name||'Untitled layout',90),viewport,nodes};
}
export function makeLayout(name='Untitled layout') {
 return normalizeLayout({version:VERSION,name,viewport:{width:800,height:500},nodes:[]});
}
export function addNode(doc,type,overrides={}) {
 const layout=normalizeLayout(doc);
 if(!NODE_TYPES.includes(type))throw new TypeError('Unknown node type');
 if(layout.nodes.length>=120)throw new RangeError('Layout node limit');
 const ids=new Set(layout.nodes.map(n=>n.id));let i=layout.nodes.length+1;
 while(ids.has('node_'+i))i++;
 return {...layout,nodes:[...layout.nodes,normalizeNode({type,id:'node_'+i,...overrides},i-1)]};
}
export function modifyNode(doc,id,changes) {
 const layout=normalizeLayout(doc);
 return {...layout,nodes:layout.nodes.map(n=>n.id===id?normalizeNode({...n,...changes,id:n.id,type:n.type}):n)};
}
export function deleteNode(doc,id) {
 const layout=normalizeLayout(doc);return {...layout,nodes:layout.nodes.filter(n=>n.id!==id)};
}
export function reorderNode(doc,id,delta) {
 const layout=normalizeLayout(doc),i=layout.nodes.findIndex(n=>n.id===id),j=i+delta;
 if(i<0||j<0||j>=layout.nodes.length||![-1,1].includes(delta))return layout;
 [layout.nodes[i],layout.nodes[j]]=[layout.nodes[j],layout.nodes[i]];return layout;
}
export function duplicateNode(doc,id) {
 const layout=normalizeLayout(doc),found=layout.nodes.find(n=>n.id===id);
 if(!found)return layout;
 return addNode(layout,found.type,{...found,id:'',x:found.x+20,y:found.y+20,role:found.role?found.role+'_copy':''});
}
/** Intentional non-game-specific integration manifest. */
export function getContract(doc) {
 const layout=normalizeLayout(doc);
 const actions=[...new Set(layout.nodes.map(n=>n.actionId).filter(Boolean))].sort();
 const bindings=[...new Set(layout.nodes.map(n=>n.bindingKey).filter(Boolean))].sort();
 return {schemaVersion:VERSION,template:layout.name,actions,bindings,
  nodes:layout.nodes.filter(n=>n.actionId||n.bindingKey).map(n=>({id:n.id,type:n.type,role:n.role,actionId:n.actionId,bindingKey:n.bindingKey}))};
}
export function parseLayout(json) {
 if(typeof json!=='string'||json.length>250000)throw new RangeError('Invalid JSON input length');
 return normalizeLayout(JSON.parse(json));
}
export function serializeLayout(doc){return JSON.stringify(normalizeLayout(doc),null,2);}
