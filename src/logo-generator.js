// Originally provided by @lydell ♥️

const b = 600 // Size of art board
const r = 28 // Gap between triangles
const m = r/2 // Offset y-wise to achieve r
const n = r*Math.sqrt(3)/2 // Offset x-wise to achieve r
const s = b/2-n // Side of triangle
const t = s*Math.sqrt(3)/2 // Height of triangle
const p = (b-m-r-2*t)/2 // Padding top and bottom

const d = (v) => Math.round(v) // Rounding

const svg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="${d(0)} ${d(0)} ${d(b)} ${d(b)}">
  <polygon fill="#5D6376" points="${d(0)},${d(b-p)} ${d(s)},${d(b-p)} ${d(s/2)},${d(b-p-t)}"/>
  <polygon fill="#2596BE" points="${d(s+2*n)},${d(b-p)} ${d(s+2*n+s)},${d(b-p)} ${d(s+2*n+s/2)},${d(b-p-t)}"/>
  <polygon fill="#9ACE50" points="${d(s/2+n)},${d(p+t)} ${d(s/2+n+s)},${d(p+t)} ${d(b/2)},${d(p)}"/>
  <polygon fill="#DDAC34" points="${d(s/2+n)},${d(p+t+r)} ${d(s/2+n+s)},${d(p+t+r)} ${d(b/2)},${d(p+t+r+t)}"/>
</svg>
`.trim()

console.log(svg);