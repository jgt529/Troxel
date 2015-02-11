'use strict'
class Renderer
  constructor: (io, @embedded = false, @domContainer = $('#WebGlContainer')) ->
    @width = @domContainer.width()
    @height = @domContainer.height() - (if @embedded then 0 else 5)
    @scene = new THREE.Scene()
    @objects = []
    @reload io, true
    # roll-over helpers
    rollOverGeo = new THREE.BoxGeometry 50, 50, 50
    rollOverMaterial = new THREE.MeshBasicMaterial color: 0xff0000, opacity: 0.5, transparent: true
    @rollOverMesh = new THREE.Mesh rollOverGeo, rollOverMaterial
    @scene.add @rollOverMesh
    # Raycaster
    @vector = new THREE.Vector3()
    @raycaster = new THREE.Raycaster()
    # Planes
    @planes = []
    geometry = new THREE.PlaneBufferGeometry 50 * @x, 50 * @y
    geometry.applyMatrix new THREE.Matrix4().makeRotationY -Math.PI / 2
    plane = new THREE.Mesh geometry
    plane.position.x = 50 * @z
    plane.position.y = 25 * @y
    plane.position.z = 25 * @x
    plane.visible = false
    @scene.add plane
    @objects.push plane
    @planes.push plane
    geometry = new THREE.PlaneBufferGeometry 50 * @z, 50 * @x
    geometry.applyMatrix new THREE.Matrix4().makeRotationX -Math.PI / 2
    plane = new THREE.Mesh geometry
    plane.position.x = 25 * @z
    plane.position.z = 25 * @x
    plane.visible = false
    @scene.add plane
    @objects.push plane
    @planes.push plane
    geometry = new THREE.PlaneBufferGeometry 50 * @y, 50 * @z
    geometry.applyMatrix new THREE.Matrix4().makeRotationZ -Math.PI / 2
    plane = new THREE.Mesh geometry
    plane.position.x = 25 * @z
    plane.position.y = 25 * @y
    plane.visible = false
    @scene.add plane
    @objects.push plane
    @planes.push plane
    # grid
    geometry = new THREE.Geometry()
    for x in [0..@x] by 1
      geometry.vertices.push new THREE.Vector3       0,       0,  50 * x # bottom grid
      geometry.vertices.push new THREE.Vector3 50 * @z,       0,  50 * x
      geometry.vertices.push new THREE.Vector3 50 * @z,       0,  50 * x # back grid
      geometry.vertices.push new THREE.Vector3 50 * @z, 50 * @y,  50 * x
    for y in [0..@y] by 1
      geometry.vertices.push new THREE.Vector3       0,  50 * y,       0 # left grid
      geometry.vertices.push new THREE.Vector3 50 * @z,  50 * y,       0
      geometry.vertices.push new THREE.Vector3 50 * @z,  50 * y,       0 # back grid
      geometry.vertices.push new THREE.Vector3 50 * @z,  50 * y, 50 * @x
    for z in [0..@z] by 1
      geometry.vertices.push new THREE.Vector3  50 * z,       0,       0 # bottom grid
      geometry.vertices.push new THREE.Vector3  50 * z,       0, 50 * @x
      geometry.vertices.push new THREE.Vector3  50 * z,       0,       0 # left grid
      geometry.vertices.push new THREE.Vector3  50 * z, 50 * @y,       0
    material = new THREE.LineBasicMaterial color: 0x000000, opacity: 0.2, transparent: true
    @grid = new THREE.Line geometry, material, THREE.LinePieces
    @scene.add @grid
    # Lights
    @ambientLight = new THREE.AmbientLight 0x606060
    @scene.add @ambientLight
    @directionalLight = new THREE.DirectionalLight 0xffffff, 0.3
    @directionalLight.position.set(-0.5, -0.5, 1).normalize()
    @scene.add @directionalLight
    @spotLight = new THREE.SpotLight 0xffffff, 0.7, 10000
    target = new THREE.Object3D()
    target.position.x = @z * 25
    target.position.y = @y * 25
    target.position.z = @x * 25
    @scene.add target
    @spotLight.target = target
    @scene.add @spotLight
    @renderer = new THREE.WebGLRenderer antialias: true
    @renderer.setClearColor 0x888888
    @renderer.setSize @width, @height
    @domContainer.empty().append @renderer.domElement
    # Stats (fps)
    unless @embedded
      @stats = new Stats()
      @stats.domElement.style.position = 'absolute'
      @stats.domElement.style.top = '0px'
      @domContainer.append @stats.domElement
    # Controls and Camera
    @camera = new THREE.PerspectiveCamera 45, @width / @height, 1, 10000
    @camera.position.x = -50 * @y - 20 * @x - 10 * @z
    @camera.position.y = @y * 50
    @camera.position.z = @x * 25
    @controls = new THREE.OrbitControls @camera, @domContainer[0]
    @controls.target = new THREE.Vector3 @z * 25, @y * 25, @x * 25
    @controls.addEventListener 'change', => @render()
    @controls.enabled = false
    @changeEditMode($('#modeEdit').parent().hasClass('active'))
    # Event handlers
    @domContainer.on        'mousedown', (e) => @onDocumentMouseDown(e)
    @domContainer.on        'mousemove', (e) => @onDocumentMouseMove(e)
    document.addEventListener 'keydown', (e) => @onDocumentKeyDown(e)
    document.addEventListener   'keyup', (e) => @onDocumentKeyUp(e)
    window.addEventListener    'resize', (e) => @onWindowResize(e)
    @animate()

  reload: (io, init = false) ->
    @voxels = io.voxels
    @x = io.x
    @y = io.y
    @z = io.z
    unless init
      @scene.remove o for o in @objects when o not in @planes
      @objects = @planes.slice 0
    for z in [0...@z] by 1 when @voxels[z]?
      for y in [0...@y] by 1 when @voxels[z]?[y]?
        for x in [0...@x] by 1 when @voxels[z]?[y]?[x]?
          color = new THREE.Color("rgb(#{@voxels[z][y][x].r},#{@voxels[z][y][x].g},#{@voxels[z][y][x].b})")
          voxel = @getVoxel color, @voxels[z][y][x].a, @voxels[z][y][x].t, @voxels[z][y][x].s
          voxel.position.x = z * 50 + 25
          voxel.position.y = y * 50 + 25
          voxel.position.z = x * 50 + 25
          @scene.add voxel
          @objects.push voxel
    @render() unless init

  getVoxel: (color, a, t, s) ->
    material = new THREE.MeshPhongMaterial color: color, ambient: color
    if t in [3, 4] # glowing solid, glowing glass
      material.emissive = material.color.multiplyScalar 0.5
    if s == 1 # metal
      material.specular = material.color.multiplyScalar 0.5
    if t in [1, 2, 4] # glass, tiled glass or glowing glass
      material.transparent = true
      material.opacity = a / 255
    return new THREE.Mesh new THREE.BoxGeometry(50, 50, 50), material

  changeEditMode: (@editMode) ->
    if @editMode
      @grid.visible = true
      @rollOverMesh.visible = true
      @controls.enabled = false
    else
      @grid.visible = false
      @rollOverMesh.visible = false
      @controls.enabled = true
    @render()

  animate: ->
    requestAnimationFrame => @animate()
    @controls.update()
    @stats.update() unless @embedded

  render: (exportPng) ->
    @spotLight.position.copy @camera.position
    @renderer.render @scene, @camera
    window.open @renderer.domElement.toDataURL('image/png'), 'Exported png' if exportPng

  onDocumentMouseMove: (e) ->
    return if !@editMode or $('#openModal').css('display') == 'block' or $('#exportModal').css('display') == 'block' or $('#saveModal').css('display') == 'block'
    e.preventDefault()
    @vector.set (e.clientX / @width) * 2 - 1, -((e.clientY - 50) / @height) * 2 + 1, 0.5
    @vector.unproject @camera
    @raycaster.ray.set @camera.position, @vector.sub(@camera.position).normalize()
    intersects = @raycaster.intersectObjects @objects
    if intersects.length > 0
      intersect = intersects[0]
      @rollOverMesh.position.copy(intersect.point).add(intersect.face.normal)
      @rollOverMesh.position.divideScalar(50).floor().multiplyScalar(50).addScalar(25)
    @render()

  onDocumentMouseDown: (e) ->
    return if !@editMode or $('#openModal').css('display') == 'block' or $('#exportModal').css('display') == 'block' or $('#saveModal').css('display') == 'block'
    getColor = (color, noiseBright, noiseHSL) ->
      if noiseBright > 0
        color.multiplyScalar Math.random() * 2 * noiseBright + 1 - noiseBright
        color.r = 1 if color.r > 1
        color.g = 1 if color.g > 1
        color.b = 1 if color.b > 1
      if noiseHSL > 0
        hsl = color.getHSL()
        hsl.h = (hsl.h + 0.1 * (Math.random() * 2 * noiseHSL - noiseHSL)) %% 1
        hsl.s = Math.max(0, Math.min(1, hsl.s + Math.random() * 2 * noiseHSL - noiseHSL))
        hsl.l = Math.max(0, Math.min(1, hsl.l + Math.random() * 2 * noiseHSL - noiseHSL))
        color.setHSL hsl.h, hsl.s, hsl.l
      return color
    @vector.set (e.clientX / @width) * 2 - 1, -((e.clientY - 50) / @height) * 2 + 1, 0.5
    @vector.unproject @camera
    @raycaster.ray.set @camera.position, @vector.sub(@camera.position).normalize()
    intersects = @raycaster.intersectObjects @objects
    if intersects.length > 0
      intersect = intersects[0]
      switch e.button
        when 0 # left mouse button
          switch $('.active .editTool').data('edittool')
            when 0 # add voxel
              color = getColor new THREE.Color($('#addVoxColor').val()), parseFloat $('#editVoxNoiseBright').val(), parseFloat $('#editVoxNoiseHSL').val()
              a = parseInt($('#addVoxAlpha').val())
              t = parseInt($('#addVoxType').val())
              s = parseInt($('#addVoxSpecular').val())
              a = 255 if t in [0, 3] # Solid
              if $('#addVoxColor').val() == '#ff00ff'
                a = 250
                t = s = 7
              voxel = @getVoxel color, a, t, s
              voxel.position.copy(intersect.point).add(intersect.face.normal)
              voxel.position.divideScalar(50).floor().multiplyScalar(50).addScalar(25)
              x = (voxel.position.z - 25) / 50
              y = (voxel.position.y - 25) / 50
              z = (voxel.position.x - 25) / 50
              return unless 0 <= x < @x and 0 <= y < @y and 0 <= z < @z
              @voxels[z] = [] unless @voxels[z]?
              @voxels[z][y] = [] unless @voxels[z][y]?
              @voxels[z][y][x] = r: Math.floor(color.r * 255), g: Math.floor(color.g * 255), b: Math.floor(color.b * 255), a: a, t: t, s: s
              @scene.add voxel
              @objects.push voxel
            when 1 # fill single voxel
              return if intersect.object in @planes
              x = (intersect.object.position.z - 25) / 50
              y = (intersect.object.position.y - 25) / 50
              z = (intersect.object.position.x - 25) / 50
              color = getColor new THREE.Color($('#addVoxColor').val()), parseFloat $('#editVoxNoiseBright').val(), parseFloat $('#editVoxNoiseHSL').val()
              a = parseInt($('#addVoxAlpha').val())
              t = parseInt($('#addVoxType').val())
              s = parseInt($('#addVoxSpecular').val())
              a = 255 if t in [0, 3] # Solid
              if color.r == 1 and color.g == 0 and color.b == 1
                a = 250
                t = s = 7
              intersect.object.material.color = intersect.object.material.ambient = color
              intersect.object.material.emissive = if t in [3, 4] then intersect.object.material.color.multiplyScalar 0.5 else new THREE.Color 0x000000
              intersect.object.material.specular = if s == 1 then intersect.object.material.color else new THREE.Color 0x111111
              intersect.object.material.transparent = t in [1, 2, 4]
              intersect.object.material.opacity = if t in [1, 2, 4] then a / 255 else 1
              @voxels[z][y][x].r = Math.floor(color.r * 255)
              @voxels[z][y][x].g = Math.floor(color.g * 255)
              @voxels[z][y][x].b = Math.floor(color.b * 255)
              @voxels[z][y][x].a = a
              @voxels[z][y][x].t = t
              @voxels[z][y][x].s = s
        when 2 # right mouse button
          return if intersect.object in @planes
          x = (intersect.object.position.z - 25) / 50
          y = (intersect.object.position.y - 25) / 50
          z = (intersect.object.position.x - 25) / 50
          switch $('.active .editTool').data('edittool')
            when 0 # delete cube
              delete @voxels[z][y][x]
              delete @voxels[z][y] if @voxels[z][y].filter((e) -> return e != undefined).length == 0
              delete @voxels[z] if @voxels[z].filter((e) -> return e != undefined).length == 0
              @scene.remove intersect.object
              @objects.splice @objects.indexOf(intersect.object), 1
            when 1 # fill area
              connected = (z, y, x) -> @voxels[z]?[y]?[x]? and !@voxels[z][y][x].filled and (!colorMatch or (v.r == @voxels[z][y][x].r and
                  v.g == @voxels[z][y][x].g and v.b == @voxels[z][y][x].b and v.a == @voxels[z][y][x].a and v.t == @voxels[z][y][x].t and v.s == @voxels[z][y][x].s))
              baseColor = $('#addVoxColor').val()
              noiseBright = parseFloat $('#editVoxNoiseBright').val()
              noiseRgb = parseFloat $('#editVoxNoiseHSL').val()
              colorMatch = $('#fillSameColor').prop('checked')
              a = parseInt($('#addVoxAlpha').val())
              t = parseInt($('#addVoxType').val())
              s = parseInt($('#addVoxSpecular').val())
              a = 255 if t in [0, 3] # Solid
              toFill = [[z, y, x]]
              @voxels[z][y][x].filled = true
              while toFill.length > 0
                [z, y, x] = toFill.pop()
                v = {r: @voxels[z][y][x].r, g: @voxels[z][y][x].g, b: @voxels[z][y][x].b, a: @voxels[z][y][x].a, t: @voxels[z][y][x].t, s: @voxels[z][y][x].s}
                color = getColor new THREE.Color(baseColor), noiseBright, noiseRgb
                @voxels[z][y][x].r = Math.floor(color.r * 255)
                @voxels[z][y][x].g = Math.floor(color.g * 255)
                @voxels[z][y][x].b = Math.floor(color.b * 255)
                @voxels[z][y][x].a = a
                @voxels[z][y][x].t = t
                @voxels[z][y][x].s = s
                if color.r == 1 and color.g == 0 and color.b == 1
                  @voxels[z][y][x].a = 250
                  @voxels[z][y][x].t = 7
                  @voxels[z][y][x].s = 7
                else
                  @voxels[z][y][x].a = a
                  @voxels[z][y][x].t = t
                  @voxels[z][y][x].s = s
                (@voxels[z    ][y    ][x + 1].filled = true; toFill.push [z    , y    , x + 1]) if connected.call @, z    , y    , x + 1
                (@voxels[z    ][y    ][x - 1].filled = true; toFill.push [z    , y    , x - 1]) if connected.call @, z    , y    , x - 1
                (@voxels[z    ][y + 1][x    ].filled = true; toFill.push [z    , y + 1, x    ]) if connected.call @, z    , y + 1, x
                (@voxels[z    ][y - 1][x    ].filled = true; toFill.push [z    , y - 1, x    ]) if connected.call @, z    , y - 1, x
                (@voxels[z + 1][y    ][x    ].filled = true; toFill.push [z + 1, y    , x    ]) if connected.call @, z + 1, y    , x
                (@voxels[z - 1][y    ][x    ].filled = true; toFill.push [z - 1, y    , x    ]) if connected.call @, z - 1, y    , x
              for z in [0...@z] by 1 when @voxels[z]?
                for y in [0...@y] by 1 when @voxels[z]?[y]?
                  for x in [0...@x] by 1 when @voxels[z]?[y]?[x]?
                    delete @voxels[z][y][x].filled if @voxels[z][y][x].filled
              io = {voxels: @voxels, x: @x, y: @y, z: @z}
              @reload io
              return history.pushState io, 'Troxel', '#m=' + new Base64IO(io).export false
        when 1 # middle mouse button => color picker
          return if intersect.object in @planes
          x = (intersect.object.position.z - 25) / 50
          y = (intersect.object.position.y - 25) / 50
          z = (intersect.object.position.x - 25) / 50
          vox = @voxels[z][y][x]
          $('#addVoxColor').val('#' + new THREE.Color("rgb(#{vox.r},#{vox.g},#{vox.b})").getHexString())
          return $('#addVoxColor').change() if vox.r == vox.b == 255 and vox.g == 0
          $('#addVoxAlpha').val(vox.a)
          $('#addVoxType').val(vox.t)
          $('#addVoxSpecular').val(vox.s)
          return $('#addVoxColor').change()
      io = {voxels: @voxels, x: @x, y: @y, z: @z}
      history.pushState io, 'Troxel', '#m=' + new Base64IO(io).export false
      @render()

  onDocumentKeyDown: (e) ->
    switch e.keyCode
      when 87 then return @controls.rotateUp   -0.05 # W
      when 65 then return @controls.rotateLeft -0.05 # A
      when 83 then return @controls.rotateUp    0.05 # S
      when 68 then return @controls.rotateLeft  0.05 # D
      when 81 then return @controls.dollyIn()        # Q
      when 69 then return @controls.dollyOut()       # E
    return if $('.active #modeView').length == 1
    switch e.keyCode
      when 18 # Alt
        @controls.enabled = true
        @editMode = false

  onDocumentKeyUp: (e) ->
    return if $('.active #modeView').length == 1
    switch e.keyCode
      when 18 # Alt
        @controls.enabled = false
        @editMode = true

  onWindowResize: ->
    @width = @domContainer.width()
    @height = @domContainer.height() - (if @embedded then 0 else 5)
    @camera.aspect = @width / @height
    @camera.updateProjectionMatrix()
    @renderer.setSize @width, @height
    @render()

if typeof module == 'object' then module.exports = Renderer else window.Renderer = Renderer
