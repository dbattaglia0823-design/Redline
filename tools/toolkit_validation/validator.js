import {NODE_TYPES, VERSION, getContract, normalizeLayout} from './schema.js';

const ACTIONABLE = new Set(['button','grid','list','slot','toggle','slider','input']);
const DATABOUND = new Set(['label','grid','list','slot','progress','toggle','slider','input']);
const LISTLIKE = new Set(['grid','list']);
const token = /^[A-Za-z][A-Za-z0-9_.-]{0,79}$/;
const finite = value => typeof value === 'number' && Number.isFinite(value);
const problem = (severity, code, message, nodeId = null) => ({severity,code,message,nodeId});

/** Validate raw input before normalization can silently repair lost or invalid fields.
 * handlerIds should be actions actually implemented by a target game, not just declared.
 * sampleData is optional; when provided, missing data paths are checked.
 */
export function validateIntegration(raw, {handlerIds, sampleData} = {}) {
 const issues = [];
 if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
  return {valid:false,ready:false,errors:[problem('error','INVALID_DOCUMENT','Layout must be a JSON object')],warnings:[],contract:null};
 }
 if (raw.version !== VERSION) issues.push(problem('error','VERSION','Expected functional layout schema version 2'));
 const viewport = raw.viewport;
 if (!viewport || !finite(viewport.width) || !finite(viewport.height) || viewport.width < 320 || viewport.height < 240 || viewport.width > 4000 || viewport.height > 4000) {
  issues.push(problem('error','VIEWPORT','Viewport must have supported numeric width and height'));
 }
 if (!Array.isArray(raw.nodes) || raw.nodes.length > 120) {
  issues.push(problem('error','NODES','Layout must contain an array of at most 120 nodes'));
 }
 if (issues.some(issue => ['VERSION','VIEWPORT','NODES'].includes(issue.code))) {
  return summarize(issues, null);
 }
 const seen = new Set(), nodes = raw.nodes;
 if (!nodes.length) issues.push(problem('warning','EMPTY','The layout contains no controls'));
 for (const [i,node] of nodes.entries()) {
  const at = node && typeof node.id === 'string' ? node.id : 'node at '+i;
  if (!node || typeof node !== 'object' || !NODE_TYPES.includes(node.type)) {
   issues.push(problem('error','TYPE','Unsupported node type',at));continue;
  }
  if (!token.test(node.id || '')) issues.push(problem('error','ID','Control ID must be a valid identifier',at));
  else if (seen.has(node.id)) issues.push(problem('error','DUPLICATE_ID','Control ID is duplicated',at));
  seen.add(node.id);
  for (const key of ['x','y','w','h']) if (!finite(node[key])) issues.push(problem('error','GEOMETRY','Invalid '+key+' coordinate',at));
  if (['x','y','w','h'].every(k=>finite(node[k]))) {
   if (node.w < 24 || node.h < 16 || node.x < 0 || node.y < 0) issues.push(problem('error','GEOMETRY','Control dimensions or position are invalid',at));
   if (node.x + node.w > viewport.width || node.y + node.h > viewport.height)
    issues.push(problem('warning','OUT_OF_BOUNDS','Control extends outside the design viewport',at));
   if (ACTIONABLE.has(node.type) && (node.w < 44 || node.h < 44))
    issues.push(problem('warning','TOUCH_TARGET','Interactive control has a target smaller than 44 design units',at));
  }
  for (const key of ['actionId','bindingKey','role']) {
   if (node[key] !== undefined && node[key] !== '' && (typeof node[key] !== 'string' || !token.test(node[key])))
    issues.push(problem('error','INVALID_'+key.toUpperCase(),'Invalid '+key+' identifier',at));
  }
  if (ACTIONABLE.has(node.type) && !node.actionId) issues.push(problem('warning','UNMAPPED_ACTION','Interactive control has no action ID',at));
  if (DATABOUND.has(node.type) && !node.bindingKey) issues.push(problem('warning','UNBOUND_DATA','Data-capable control has no data binding',at));
  if (LISTLIKE.has(node.type) && node.actionId && !node.bindingKey)
   issues.push(problem('warning','EMPTY_COLLECTION','Selectable collection has no source array',at));
  if (handlerIds !== undefined && node.actionId && !new Set(handlerIds).has(node.actionId))
   issues.push(problem('warning','MISSING_HANDLER','Action has no matching target-game handler',at));
  if (sampleData !== undefined && node.bindingKey && !lookup(sampleData,node.bindingKey).found)
   issues.push(problem('warning','MISSING_DATA','Binding key not found in sample game data',at));
  if (sampleData !== undefined && node.bindingKey) {
   const found=lookup(sampleData,node.bindingKey);
   if (found.found && LISTLIKE.has(node.type) && !Array.isArray(found.value))
    issues.push(problem('error','EXPECTED_ARRAY','Grid/list binding must resolve to an array',at));
   if (found.found && node.type==='progress' && (!finite(Number(found.value)) || Number(found.value)<0 || Number(found.value)>100))
    issues.push(problem('warning','PROGRESS_RANGE','Progress binding should be a value between 0 and 100',at));
  }
 }
 if (issues.some(x=>x.severity==='error')) return summarize(issues,null);
 let contract;
 try { contract=getContract(normalizeLayout(raw)); }
 catch(e) { issues.push(problem('error','SCHEMA',e.message)); }
 return summarize(issues,contract??null);
}

function lookup(data,key) {
 if (data==null || typeof data!=='object')return {found:false};
 if (Object.hasOwn(data,key))return {found:true,value:data[key]};
 let node=data;
 for(const part of key.split('.')){
  if(node==null || typeof node!=='object' || !Object.hasOwn(node,part))return {found:false};
  node=node[part];
 }
 return {found:true,value:node};
}
function summarize(issues,contract) {
 const errors=issues.filter(i=>i.severity==='error');
 const warnings=issues.filter(i=>i.severity==='warning');
 return {valid:errors.length===0,ready:errors.length===0&&warnings.length===0,errors,warnings,contract};
}
