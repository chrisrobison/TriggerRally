define [
  'backbone-full'
  'cs!views/view'
  'cs!views/statusbar'
  'cs!client/client'
  'jade!templates/unified'
  'cs!util/popup'
], (
  Backbone
  View
  StatusBarView
  TriggerClient
  template
  popup
) ->
  $ = Backbone.$

  class UnifiedView extends View
    el: '#unified-container'
    template: template

    constructor: (@app) ->
      super()
      # We maintain 2 view references, one for 3D and one for DOM.
      # They may be the same or different.
      @currentView3D = null     # Controls 3D rendering.
      @currentViewChild = null  # Controls DOM.

    afterRender: ->
      statusBarView = new StatusBarView @app
      statusBarView.render()

      $window = $(window)
      $document = $(document)
      $view3d = @$('#view3d')
      $child = @$('#unified-child')

      client = @client = new TriggerClient $view3d[0], @app.root
      client.camera.eulerOrder = 'ZYX'

      $document.on 'keyup', (event) -> client.onKeyUp event
      $document.on 'keydown', (event) -> client.onKeyDown event

      do layout = ->
        statusbarHeight = statusBarView.height()
        $view3d.css 'top', statusbarHeight
        $child.css 'top', statusbarHeight
        width = $view3d.width()
        height = $window.height() - statusbarHeight
        $view3d.height height
        client.setSize width, height

        cx = 32
        cy = 18
        targetAspect = cx / cy
        aspect = width / height
        fontSize = if aspect >= targetAspect then height / cy else width / cx
        $child.css "font-size", "#{fontSize}px"
      $window.on 'resize', layout

      $document.on 'click', 'a.route', (event) ->
        Backbone.history.navigate @pathname, trigger: yes
        no

      $document.on 'click', 'a.login', (event) ->
        not popup.create "/login?popup=1", "Login", ->
          Backbone.trigger 'app:checklogin'

      $document.on 'click', 'a.logout', (event) ->
        $.ajax('/v1/auth/logout')
        .done (data) ->
          Backbone.trigger 'app:logout'
        false

      requestAnimationFrame @update

    lastTime = null
    update: (time) =>
      lastTime or= time
      deltaTime = Math.max 0, Math.min 0.1, (time - lastTime) * 0.001
      lastTime = time

      @currentView3D?.update? deltaTime, time
      if @currentViewChild isnt @currentView3D
        @currentViewChild?.update? deltaTime, time

      @client.update deltaTime
      @client.render()

      requestAnimationFrame @update

    getView3D: -> @currentView3D
    getViewChild: -> @currentViewChild

    setView3D: (view) ->
      if @currentView3D
        @currentView3D.destroy()
      @currentView3D = view
      return

    setViewChild: (view) ->
      container = $('#unified-child')
      if @currentViewChild
        @currentViewChild.destroy()
        container.empty()
      @currentViewChild = view
      container.append view.el if view
      return