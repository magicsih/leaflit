export function createStylesheetLoader(document, id, href) {
  let ready;
  return () => {
    // An inserted link can still be loading when a newer revision arrives.
    if (!ready) ready = new Promise(resolve => {
      const link = document.createElement('link');
      link.id = id; link.rel = 'stylesheet'; link.href = href;
      const settle = () => {
        link.removeEventListener('load', settle);
        link.removeEventListener('error', settle);
        resolve();
      };
      link.addEventListener('load', settle, { once: true });
      link.addEventListener('error', settle, { once: true });
      document.head.append(link);
    });
    return ready;
  };
}
