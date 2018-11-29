-- game.lua : A state machine to control the game

local log = require('log')
local animate = require('animate')
local util = require('util')
local maps = {
    'forward',
}

local game = {
    state = require('lib.Stack'):new(),
    models = {},
    views = {},
    controllers = {},
    event = {
        handlers = love.handlers,
        poll = love.event.poll,
        clear = love.event.clear,
    },
    maps = {
        _current = 1,
    },
    script = {
        raw = '',
        parsed = {},
    },
    intervals = {
        mapStep = 1,
    },
}

function game.event.add(stateName, event, cb)
    log.debug('game.event.add: ' .. stateName .. ': ' .. event)
    game.controllers[stateName][event] = cb
end

function game.maps.current()
    return maps[game.maps._current]
end

function game.event.push(event, args)
    local state = game.state:top()
    log.debug('game.event.push: ' .. state .. ': ' .. event)
    love.event.push(state, event, args)
end

function game.event.handlers.nextMap()
    local current = game.maps._current + 1
    if maps[current] then
        game.maps._current = current
    else
        love.event.quit()
    end
end

function game.event.handlers.resetMap()
    game.maps._current = 1
end

function game.event.handlers.scriptSubmit(args)
    log.debug('game.scriptSubmit: ' .. args[1])
    game.script.raw = args[1]
    game.script.parsed = util.newParsedScript(args[1])
    if not game.script.parsed then
        game.event.push('scriptError')
    else
        game.event.push('run')
    end
end

function game.event.handlers.run()
    globals.timer.reset('map')
    globals.timer.start('map')
end

function game.event.handlers.startGame()
    log.debug('game.startGame: starting new game: ' .. game.maps.current())
    game.models.Map:load(game.maps.current())
    game.views.Map:update()
    animate.reset()
    game.state:push('Map')
end

function game.event.handlers.endGame(args)
    log.debug('game.endGame: we ' .. args[1])
    globals.timer.stop('map')
    if args[1] == 'win' then
        game.event.push('nextMap')
        game.event.push('startGame')
    else
        game.models.Map:reset()
        game.views.Map:update()
    end
end

function game.loadComponent(component)
    log.debug('game.loadComponent: ' .. component)
    local model = require('models.' .. component):new({ name = component })
    game.models[component] = model
    game.views[component] = require('views.' .. component):new(model)
    game.controllers[component] = require('controllers.' .. component)
    game.event.handlers[component] = util.newEventHandler(
            game.controllers[component], model)
end

function game.animateMap(callback)
    log.info('Animating map')
    callback()
end

function game.load()
    game.loadComponent('Menu')
    game.loadComponent('Map')

    game.models.Menu:addItem('New Game', function()
        log.debug('Menu: new game')
        game.event.push('resetMap')
        game.event.push('startGame')
    end)
    game.models.Menu:addItem('Load Game', function()
        log.debug('Menu: load game')
        love.event.quit()  -- TODO
    end)
    game.models.Menu:addItem('Save Game', function()
        log.debug('Menu: save game')
        love.event.quit()  -- TODO
    end)
    game.models.Menu:addItem('How to Play', function()
        log.debug('Menu: how to play')
        love.event.quit()  -- TODO
    end)
    game.models.Menu:addItem('Exit', function()
        log.debug('Menu: quit')
        love.event.quit()  -- TODO
    end)
    game.models.Menu:setHighlighted(1)

    local width, height = love.graphics.getPixelDimensions()
    game.views.Menu:load(width, height)
    game.views.Map:load(width, height)

    animate.reset()
    game.state:push('Menu')

    globals.timer.track('map')
end

function game.draw()
    game.views[game.state:top()]:draw()
end

function game.update()
    if game.state:top() == 'Map'
            and globals.timer.getTime('map') > game.intervals.mapStep then
        globals.timer.reset('map')
        game.event.push('step')
    end
end

return game
