// Render ```mermaid code blocks.
// Jekyll outputs them as <pre><code class="language-mermaid">; Mermaid needs <pre class="mermaid">.
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs';

document.querySelectorAll('code.language-mermaid').forEach((code) => {
  const pre = document.createElement('pre');
  pre.className = 'mermaid';
  pre.textContent = code.textContent;
  code.closest('pre').replaceWith(pre);
});

mermaid.initialize({ startOnLoad: false, theme: 'default' });
await mermaid.run({ querySelector: 'pre.mermaid' });
