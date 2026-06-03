"use strict";(self.webpackChunk_N_E=self.webpackChunk_N_E||[]).push([[526],{9526:function(t,e,r){r.d(e,{Z:function(){return O}});var a=r(3366),n=r(7462),i=r(7294),o=r(512),s=r(917),l=r(8510),h=r(8758),d=r(2358),u=r(948),p=r(1657),g=r(1977),c=r(5463);function f(t){return(0,c.ZP)("MuiSkeleton",t)}(0,g.Z)("MuiSkeleton",["root","text","rectangular","rounded","circular","pulse","wave","withChildren","fitContent","heightAuto"]);var m=r(5893);let b=["animation","className","component","height","style","variant","width"],v=t=>t,w,$,k,y,C=t=>{let{classes:e,variant:r,animation:a,hasChildren:n,width:i,height:o}=t;return(0,l.Z)({root:["root",r,a,n&&"withChildren",n&&!i&&"fitContent",n&&!o&&"heightAuto"]},f,e)},x=(0,s.F4)(w||(w=v`
  0% {
    opacity: 1;
  }

  50% {
    opacity: 0.4;
  }

  100% {
    opacity: 1;
  }
`)),Z=(0,s.F4)($||($=v`
  0% {
    transform: translateX(-100%);
  }

  50% {
    /* +0.5s of delay between each loop */
    transform: translateX(100%);
  }

  100% {
    transform: translateX(100%);
  }
`)),R=(0,u.ZP)("span",{name:"MuiSkeleton",slot:"Root",overridesResolver:(t,e)=>{let{ownerState:r}=t;return[e.root,e[r.variant],!1!==r.animation&&e[r.animation],r.hasChildren&&e.withChildren,r.hasChildren&&!r.width&&e.fitContent,r.hasChildren&&!r.height&&e.heightAuto]}})(({theme:t,ownerState:e})=>{var r,a;let i=String(t.shape.borderRadius).match(/[\d.\-+]*\s*(.*)/)[1]||"px",o=parseFloat(t.shape.borderRadius);return(0,n.Z)({display:"block",backgroundColor:t.vars?t.vars.palette.Skeleton.bg:(r=t.palette.text.primary,a="light"===t.palette.mode?.11:.13,r=function t(e){let r;if(e.type)return e;if("#"===e.charAt(0))return t(function(t){t=t.slice(1);let e=RegExp(`.{1,${t.length>=6?2:1}}`,"g"),r=t.match(e);return r&&1===r[0].length&&(r=r.map(t=>t+t)),r?`rgb${4===r.length?"a":""}(${r.map((t,e)=>e<3?parseInt(t,16):Math.round(parseInt(t,16)/255*1e3)/1e3).join(", ")})`:""}(e));let a=e.indexOf("("),n=e.substring(0,a);if(-1===["rgb","rgba","hsl","hsla","color"].indexOf(n))throw Error((0,h.Z)(9,e));let i=e.substring(a+1,e.length-1);if("color"===n){if(r=(i=i.split(" ")).shift(),4===i.length&&"/"===i[3].charAt(0)&&(i[3]=i[3].slice(1)),-1===["srgb","display-p3","a98-rgb","prophoto-rgb","rec-2020"].indexOf(r))throw Error((0,h.Z)(10,r))}else i=i.split(",");return{type:n,values:i=i.map(t=>parseFloat(t)),colorSpace:r}}(r),a=function(t,e=0,r=1){return(0,d.Z)(t,e,r)}(a),("rgb"===r.type||"hsl"===r.type)&&(r.type+="a"),"color"===r.type?r.values[3]=`/${a}`:r.values[3]=a,function(t){let{type:e,colorSpace:r}=t,{values:a}=t;return -1!==e.indexOf("rgb")?a=a.map((t,e)=>e<3?parseInt(t,10):t):-1!==e.indexOf("hsl")&&(a[1]=`${a[1]}%`,a[2]=`${a[2]}%`),`${e}(${a=-1!==e.indexOf("color")?`${r} ${a.join(" ")}`:`${a.join(", ")}`})`}(r)),height:"1.2em"},"text"===e.variant&&{marginTop:0,marginBottom:0,height:"auto",transformOrigin:"0 55%",transform:"scale(1, 0.60)",borderRadius:`${o}${i}/${Math.round(o/.6*10)/10}${i}`,"&:empty:before":{content:'"\\00a0"'}},"circular"===e.variant&&{borderRadius:"50%"},"rounded"===e.variant&&{borderRadius:(t.vars||t).shape.borderRadius},e.hasChildren&&{"& > *":{visibility:"hidden"}},e.hasChildren&&!e.width&&{maxWidth:"fit-content"},e.hasChildren&&!e.height&&{height:"auto"})},({ownerState:t})=>"pulse"===t.animation&&(0,s.iv)(k||(k=v`
      animation: ${0} 2s ease-in-out 0.5s infinite;
    `),x),({ownerState:t,theme:e})=>"wave"===t.animation&&(0,s.iv)(y||(y=v`
      position: relative;
      overflow: hidden;

      /* Fix bug in Safari https://bugs.webkit.org/show_bug.cgi?id=68196 */
      -webkit-mask-image: -webkit-radial-gradient(white, black);

      &::after {
        animation: ${0} 2s linear 0.5s infinite;
        background: linear-gradient(
          90deg,
          transparent,
          ${0},
          transparent
        );
        content: '';
        position: absolute;
        transform: translateX(-100%); /* Avoid flash during server-side hydration */
        bottom: 0;
        left: 0;
        right: 0;
        top: 0;
      }
    `),Z,(e.vars||e).palette.action.hover)),S=i.forwardRef(function(t,e){let r=(0,p.Z)({props:t,name:"MuiSkeleton"}),{animation:i="pulse",className:s,component:l="span",height:h,style:d,variant:u="text",width:g}=r,c=(0,a.Z)(r,b),f=(0,n.Z)({},r,{animation:i,component:l,variant:u,hasChildren:Boolean(c.children)}),v=C(f);return(0,m.jsx)(R,(0,n.Z)({as:l,ref:e,className:(0,o.Z)(v.root,s),ownerState:f},c,{style:(0,n.Z)({width:g,height:h},d)}))});var O=S}}]);