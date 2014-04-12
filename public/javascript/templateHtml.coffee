"""
This is a hack to avoid having to manually pre-compile the Handlebars templates.
"""

window.buildTemplates = =>
  
  # Treat these as HTML files
  quizHandlebars = """
  <div class="quiz_title">Quiz time!</div>
  <p>How well do you know {{fromUser}}?</p>
  <video autoplay="" loop="" width="320"><source src="{{videoUrl}}" type="video/webm"></video>
  <div id="quiz-buttons" class="quiz-choices">
    {{#each quizChoices}}
      <button class='quiz-choice {{correct}}'>{{emoticon}}</button>
    {{/each}}
  </div>
  """

  # Add any new templates to this dictionary so that they get compiled.
  handlebarsElems = {"quiz": quizHandlebars}
  return handlebarsElems

# Access templates via window.Templates["quiz"] for example, depending on the name given in
# handlebarsElems
window.Templates = {}
for name, templateStr of window.buildTemplates()
  window.Templates[name] = Handlebars.compile(templateStr)