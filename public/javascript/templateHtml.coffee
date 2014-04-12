"""
This is a hack to avoid having to manually pre-compile the Handlebars templates.
"""

window.buildTemplates = =>
  
  # Treat these as HTML files
  quizHandlebars = """
  <h1>Quiz time!</h1>
  <video autoplay="" loop="" width="120"><source src="{{videoUrl}}" type="video/webm"></video>
  <h3>{{fromUser}}</h3>
  <div class='quiz-choices'>
    {{#each quizChoices}}
      <span class='quiz-choice {{correct}}'>{{emoticon}}</span>
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