// Tema claro u oscuro. Sin preferencia guardada manda el sistema (prefers-color-scheme);
// al pulsar el botón se guarda la elección. Sin JS la página sigue el sistema y el botón no aparece.
(function () {
  var KEY = 'theme';
  var root = document.documentElement;
  var media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function stored() {
    try { var v = localStorage.getItem(KEY); return v === 'light' || v === 'dark' ? v : null; } catch (e) { return null; }
  }
  function effective() {
    return root.getAttribute('data-theme') || (media && media.matches ? 'dark' : 'light');
  }

  var saved = stored();
  if (saved) root.setAttribute('data-theme', saved);

  document.addEventListener('DOMContentLoaded', function () {
    var btn = document.querySelector('[data-theme-toggle]');
    if (!btn) return;
    function sync() { btn.setAttribute('aria-pressed', effective() === 'dark' ? 'true' : 'false'); }
    btn.hidden = false;
    sync();
    btn.addEventListener('click', function () {
      var next = effective() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem(KEY, next); } catch (e) { /* sin almacenamiento: vale para esta visita */ }
      sync();
    });
    if (media && media.addEventListener) media.addEventListener('change', sync);
  });
})();
