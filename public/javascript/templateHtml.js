// Generated by CoffeeScript 1.6.3
(function() {
  "This is a hack to avoid having to manually pre-compile the Handlebars templates.";
  var name, templateStr, _ref,
    _this = this;

  window.buildTemplates = function() {
    var handlebarsElems, powerupAvailableHandlebars, powerupHandlebars, quizHandlebars;
    quizHandlebars = "<div class=\"indiv_quiz_container {{forWhomClass}}\">\n  <div class=\"quiz_title\">Face off!</div>\n  <p>{{challengeMessage}}</p>\n  <video autoplay=\"\" loop=\"\" width=\"320\"><source src=\"{{videoUrl}}\" type=\"video/webm\"></video>\n  {{#each quizChoices}}\n    <button class='quiz-choice {{correct}}'>{{emoticon}}</button>\n  {{/each}}\n</div>";
    powerupHandlebars = "<div class=\"quiz_title\">Use emoticons while chatting to power up for a face off!</div>\n<p>Two users need to have at least {{numRequiredVideos}} emoticon videos available to start!</p>\n<p>Once every user is ready, a quiz will be triggered.</p>\n<div class=\"powerup_available_videos\">\n\n</div>\n\n<div class=\"progress-wrap progress\" data-progress-percent=\"0\">\n  <div class=\"progress-bar progress\"></div>\n</div>\n<p id=\"powerup_encouragement\"></p>";
    powerupAvailableHandlebars = "{{#each usersAvailable}}\n  <div class=\"powerup-user-available\">\n    <span class=\"powerup-username\">{{username}}:</span>\n    <span class=\"powerup-num-available\">{{numAvailable}}</span>\n    <span class=\"is-ready\">\n    {{#if enoughVideos}}\n      <span class=\"powerup-user-ready\">\n        (Ready!)\n      </span>\n    {{else}}\n      <span class=\"powerup-user-not-ready\">\n        (Keep using emoticons!)\n      </span\n    {{/if}}\n    </span>\n  </div>\n{{/each}}";
    handlebarsElems = {
      "quiz": quizHandlebars,
      "powerup": powerupHandlebars,
      "powerup_available": powerupAvailableHandlebars
    };
    return handlebarsElems;
  };

  window.Templates = {};

  _ref = window.buildTemplates();
  for (name in _ref) {
    templateStr = _ref[name];
    window.Templates[name] = Handlebars.compile(templateStr);
  }

}).call(this);
