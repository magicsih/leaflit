const status = document.querySelector('#copy-status');
for (const button of document.querySelectorAll('[data-copy]')) {
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      status.textContent = 'Install command copied.';
    } catch {
      status.textContent = 'Select and copy the install command above.';
    }
  });
}
