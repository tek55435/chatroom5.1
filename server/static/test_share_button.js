var btn = document.createElement('button');
btn.textContent = 'Test Share Functions';
btn.style.position = 'fixed';
btn.style.bottom = '20px';
btn.style.right = '20px';
btn.style.zIndex = '9999';
btn.style.backgroundColor = '#4CAF50';
btn.style.color = 'white';
btn.style.padding = '10px';
btn.style.border = 'none';
btn.style.cursor = 'pointer';
btn.onclick = function() {
    console.log('Test button clicked');
    if (typeof ShareDebug === 'object') {
        ShareDebug.testShareFunctions();
        ShareDebug.testShare();
    } else {
        console.error('ShareDebug not found');
        alert('ShareDebug not found - check console for details');
    }
};
document.body.appendChild(btn);
console.log('Test share button added to page');
