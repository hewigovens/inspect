var InspectActionExtension = function() {};

InspectActionExtension.prototype = {
  run: function(parameters) {
    parameters.completionFunction({
      url: document.URL || "",
      title: document.title || "",
      selection: window.getSelection ? String(window.getSelection()) : ""
    });
  }
};

var ExtensionPreprocessingJS = new InspectActionExtension();
