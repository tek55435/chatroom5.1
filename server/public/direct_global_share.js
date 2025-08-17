window.directChatShare = function(url) {
    console.log('DIRECT GLOBAL directChatShare called with URL:', url);
    alert('Share button clicked with URL: ' + url);
    try {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(url);
            alert('Chat URL copied to clipboard: ' + url);
        } else {
            var textarea = document.createElement('textarea');
            textarea.value = url;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
            alert('Chat URL copied to clipboard: ' + url);
        }
        return true;
    } catch(e) {
        alert('Please copy this URL manually: ' + url);
        return false;
    }
};
console.log('Direct Global Share function installed');
