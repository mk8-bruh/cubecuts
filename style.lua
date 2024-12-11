return {
    background = {
        color = {1, 1, 1}
    },
    title = {
        text = {
            color = {0, 0, 0},
            font = love.graphics.newFont(40)
        }
    },
    message = {
        text = {
            color = {0, 0, 0},
            font = love.graphics.newFont(30)
        }
    },
    footer = {
        text = {
            color = {0.6, 0.6, 0.6},
            font = love.graphics.newFont(20)
        }
    },
    button = {
        shape = {
            padding = {
                x = 8,
                y = 5
            },
            cornerRadius = 5
        },
        color = {
            default = {1, 1, 1},
            active = {1, 1, 0.4},
            hovered = {1, 1, 0.8},
            pressed = {0, 0, 0}
        },
        text = {
            color = {
                default = {0, 0, 0},
                active = {0, 0, 0},
                hovered = {0, 0, 0},
                pressed = {1, 1, 1}
            },
            font = love.graphics.newFont(20)
        },
        outline = {
            color = {
                default = {0, 0, 0},
                active = {0, 0, 0},
                hovered = {0, 0, 0},
                pressed = {0, 0, 0}
            },
            width = 2
        }
    },
    textbox = {
        shape = {
            padding = {
                x = 8,
                y = 5
            },
            cornerRadius = 5
        },
        color = {
            default = {0.625, 0.625, 0.625},
            active = {0.75, 0.75, 0.5},
            hovered = {0.75, 0.75, 0.75}
        },
        text = {
            color = {
                default = {1, 1, 1},
                active = {1, 1, 1},
                hovered = {1, 1, 1}
            },
            font = love.graphics.newFont(15)
        },
        cursor = {
            color = {1, 1, 1},
            width = 1,
            blinkSpeed = 1
        },
        alttext = {
            color = {0.25, 0.25, 0.25},
            font = love.graphics.newFont(15)
        },
        outline = {
            color = {
                default = {0, 0, 0},
                active = {0, 0, 0},
                hovered = {0, 0, 0}
            },
            width = 1
        }
    }
}