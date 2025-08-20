// Debug logger for share functionality 
window.addEventListener('DOMContentLoaded', function() { 
  console.log('Share console logger activated'); 
  window.originalDirectChatShare = window.directChatShare; 
  window.directChatShare = function(url) { 
    console.log('directChatShare called with URL:', url); 
    if (window.originalDirectChatShare) { 
      return window.originalDirectChatShare(url); 
    } else { 
      alert('Share function called successfully with URL: ' + url); 
      return true; 
    } 
  }; 
  console.log('Share console logger: directChatShare function enhanced'); 
}); 
