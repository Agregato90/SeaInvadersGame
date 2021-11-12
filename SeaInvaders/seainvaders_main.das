require daslib/media

struct WaveMesh
    coord: array<float2>
    uv: array<float2>
    color: uint
    count: int

struct WaterExplosion
    coord: float2
    curTime: float
    strength: float
    curStrength: float
    rad: float
    radMul: float
    fadeMul: float
    visualSize: float2
    visualLifetime: float

struct AerialExplosion
    coord: float2
    curTime: float
    strength: float
    curStrength: float
    rad: float
    maxRad: float

struct Player
    coord: float2
    speed: float2
    angle: float
    health: float
    size: float
    weaponReload: float

struct Enemy
    coord: float2
    phase: float
    speed: float    
    health: float
    startHealth: float
    deathState: int
    deathWaterSplash: int
    fireEffect: int
    angle: float
    size: float2
    color: float4
    colorLights: float4
    weapon: int4
    weaponReload: float4
    weaponReloadSpeed: float4
    score: int

struct EnemyBullet
    coord: float2
    target: float2
    speed: float2
    maxSpeed: float
    damage: float
    size: float
    visual: int
    hitAnim: int
    explosionType: int

struct PlayerBullet
    coord: float2
    speed: float2
    maxSpeed: float
    damage: float
    size: float
    visual: int

struct BulletVisual
    size: float
    count: int
    trace: float
    color0: float4
    color1: float4
    part: int

struct Particle
    bmap: Image
    ablendMode: int

var
    sea_wave_gradient: Image
    sky_gradient: Image
    player_ship: Image
    enemy_ship: array<Image>
    water_splash: Image
    particles: array<Particle>

    waves: array<WaveMesh>

    enemyBullets: array<EnemyBullet>
    playerBullets: array<PlayerBullet>
    waterExplosions: array<WaterExplosion>
    aerialExplosions: array<AerialExplosion>
    enemies: array<Enemy>
    player: Player

    enemyTypes: array<Enemy>
    enemyBulletTypes: array<EnemyBullet>
    playerBulletTypes: array<PlayerBullet>
    waterExplosionTypes: array<WaterExplosion>

    bulletVisuals: array<BulletVisual>

    globalSw: float
    globalSh: float

    seed = int4(762, 22, 3, 4)
    maxScore: int
    totalScore: int
    healthRegain: int
    enemyMaxLevel: float

    explAdd : float
    seaLevel = 0.2
    aliveEnemyCount: int
    waveCount = 20
    layerThickness = seaLevel / float(waveCount)
    gameStarted : bool
    gameDelay: float


def reset_game
    clear(enemyBullets)
    clear(playerBullets)
    clear(waterExplosions)
    clear(aerialExplosions)
    clear(enemies)

    player.coord = float2(0.5, 0.5)
    player.speed = float2(0.0, 0.0)
    player.angle = 0.0
    player.weaponReload = 0.0
    player.health = 1.0
    player.size = 0.05

    maxScore = max(maxScore, totalScore)
    totalScore = 0
    healthRegain = 0

    enemyMaxLevel = 0.0
    aliveEnemyCount = 0
    gameStarted = false
    gameDelay = 1.0

def addTypedWaterExplosion(etype: int; pos: float2)
    for x in waterExplosions
        if x.strength < 0.0
            x = waterExplosionTypes[etype]
            x.coord = pos
            return
    
    var x = waterExplosionTypes[etype]
    x.coord = pos
    waterExplosions |> push(x)

def addTypedEnemy(etype: int; phase: float; posY: float)
    for x in enemies
        if x.deathState < 0
            x = enemyTypes[etype]
            x.phase = phase
            x.coord.y = posY
            x.speed*=rnd(0.7, 1.5)
            return
    var x = enemyTypes[etype]
    x.phase = phase
    x.coord.y = posY
    x.speed*=rnd(0.7, 1.5)
    enemies |> push(x)

def addTypedEnemyBullet(btype: int; pos: float2; targ: float2)
    if btype < 0
        return
    var target = targ + float2(rnd(-0.01, 0.01), rnd(-0.01, 0.01))
    for x in enemyBullets
        if x.damage <= 0.0
            x = enemyBulletTypes[btype]
            x.coord = pos
            x.target = target 
            x.speed = x.maxSpeed*(float2(target.x, 1.0 - target.y*seaLevel)-pos)
            return
    
    var x = enemyBulletTypes[btype]
    x.coord = pos
    x.target = target 
    x.speed = x.maxSpeed*(float2(target.x, 1.0 - target.y*seaLevel)-pos)
    enemyBullets |> push(x)

def addTypedPlayerBullet(btype: int; angle : float)
    if btype < 0
        return
    for x in playerBullets
        if x.damage <= 0.0
            x = playerBulletTypes[btype]
            x.coord = float2(player.coord.x, 1.0 - seaLevel*player.coord.y)
            x.speed = -x.maxSpeed*(float2(-sin(angle), cos(angle)))
            return
    
    var x = playerBulletTypes[btype]
    x.coord = float2(player.coord.x, 1.0 - seaLevel*player.coord.y)
    x.speed = -x.maxSpeed*(float2(-sin(angle), cos(angle)))
    playerBullets |> push(x)


def wave_simulation(pos: float2)
    var retVal = 0.0

    for x in waterExplosions
        if x.curStrength <= 0.0
            continue
        let explLen = length(pos - x.coord)
        if explLen >= x.rad
            continue
        var expStrength = explLen/x.rad
        expStrength = x.curStrength * (1.0 - expStrength * expStrength)
        retVal += expStrength*cos(100.0*explLen-5.0*x.curTime)

    return retVal


def smoothstep(x)
    let t = saturate(x)
    return t * t * (3.0 - 2.0 * t)


def rnd(from, to): float
    return float(from) + random_float(seed) * (float(to) - float(from))


def wave_mesh(var m: WaveMesh &; pos: float2; color_: uint; count: int; width: float; strip_thickness : float)
    m.color = color_
    m.count = count
    var p = pos
    p.y += strip_thickness
    var incr = width / float(count)
    m.coord |> push(p)
    m.uv |> push(float2(0, 0))
    for i in range(count)
        m.coord |> push(p + float2(0.0, 10.0))
        m.uv |> push(float2(0, 3))
        m.coord |> push(p + float2(incr, 0.0))
        m.uv |> push(float2(0, 0))
        p += float2(incr, 0.0)

    m.coord |> push(back(m.coord))
    m.uv |> push(back(m.uv))


[export]
def initialize
    set_window_title("Sea Invaders: The Movie: The Game")
    set_antialiasing(4)
    explAdd = 0.0
    maxScore = 0

    //////////////////////////
    // TEXTURES AND MESHES
    //////////////////////////

    sea_wave_gradient <- create_image(1, 3, [{uint[] make_color(0.0, 0.0, 1.0);
                                                     make_color(0.1, 0.7, 0.9);
                                                     make_color(1.0, 1.0, 1.0)}])
    sea_wave_gradient |> set_image_smooth(true)

    sky_gradient <- create_image(2, 2, [{uint[] make_color(0.5, 0.7, 1.0);  make_color(0.25, 0.6, 0.8);
                                                make_color(0.7, 0.7, 1.0); make_color(0.5, 0.5, 0.8)}])
    sky_gradient |> set_image_smooth(true)

    let particle_rad = 32
    particles |> resize(3)
    particles[0].bmap <- create_image(particle_rad*2, particle_rad*2)
    particles[0].bmap |> set_image_smooth(true)
    particles[0].ablendMode = 1
    particles[1].bmap <- create_image(particle_rad*2, particle_rad*2)
    particles[1].bmap |> set_image_smooth(true)
    particles[1].ablendMode = 0
    particles[2].bmap <- create_image(particle_rad*2, particle_rad*2)
    particles[2].bmap |> set_image_smooth(true)
    particles[2].ablendMode = 0
    for iy in range(particle_rad*2)
        for ix in range(particle_rad*2)
            let x = float(ix - particle_rad) / float(particle_rad)
            let y = float(iy - particle_rad) / float(particle_rad)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len + (sin(angle * 10.0) + sin(angle * 18.0) + sin(angle * 34.0)) * 0.02 * len * len
            particles[0].bmap |> set_pixel(ix, iy, make_color(smoothstep(1.0 - k), 0.0))
            var bk = max(0.0, 1.0-len*len*len)*(cos(10.0*len + angle))
            particles[1].bmap |> set_pixel(ix, iy, make_color(1.0, bk))
            bk = 0.125 * (4.0 + sin((x+y)*16.0) + cos((y+x)*6.0) + cos((x-y)*11.0) + sin((y-x)*20.0))
            bk = bk
            particles[2].bmap |> set_pixel(ix, iy, make_color(1.0, bk*smoothstep(1.0 - k)))

    let enemy_rad = 32
    enemy_ship |> resize(2)
    enemy_ship[0] <- create_image(enemy_rad*2, enemy_rad*2)
    enemy_ship[0] |> set_image_smooth(true)
    enemy_ship[1] <- create_image(enemy_rad*2, enemy_rad*2)
    enemy_ship[1] |> set_image_smooth(true)
    for iy in range(enemy_rad*2)
        for ix in range(enemy_rad*2)
            let x = float(ix - enemy_rad) / float(enemy_rad)
            let y = float(iy - enemy_rad) / float(enemy_rad)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len
            enemy_ship[0] |> set_pixel(ix, iy, make_color(0.7-0.15*(x + y), 10.0 - 10.0*k))
            var bk = 0.125 * (4.0 + sin(x*y*16.0) + cos((y+x)*6.0) + cos((x-y)*11.0) + sin(y*x*20.0))
            bk = bk*bk*bk*bk
            enemy_ship[1] |> set_pixel(ix, iy, make_color(0.0, bk*(10.0 - 10.0*k)))

    let watersplash_rad = 32
    water_splash <- create_image(watersplash_rad*2, watersplash_rad*2)
    water_splash |> set_image_smooth(true)
    for iy in range(watersplash_rad*2)
        for ix in range(watersplash_rad*2)
            let x = float(ix - watersplash_rad) / float(watersplash_rad)
            let y = 1.0 - float(iy) / float(watersplash_rad*2)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len
            let bk = 0.125 * (4.0 + sin(x*y*11.0) + cos((y+x)*11.0) + cos((x-y)*6.0) + cos(y*x*5.0))
            water_splash |> set_pixel(ix, iy, make_color((0.75+0.125*(y-x))*bk*min(y*10.0 - 2.0*x*x, 1.0)*clamp(3.0 - 3.0*k, 0.0, 1.0), 0.0))

    let playership_rad = 32
    player_ship <- create_image(playership_rad*2, playership_rad*2)
    player_ship |> set_image_smooth(true)
    for iy in range(playership_rad*2)
        for ix in range(playership_rad*2)
            let x = float(iy - playership_rad) / float(playership_rad)
            let y = 1.0 - float(ix) / float(playership_rad*2)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len
            let bk = 1.0
            player_ship |> set_pixel(ix, iy, make_color(0.75+0.125*(y-x), bk*min(y*5.0 + 4.0 - 8.0*abs(x), 1.0)))

    let sw = float(get_screen_width())
    let sh = float(get_screen_height())

    waves |> resize(waveCount)
    for x, i in waves, range(99999)
        let k = float(i) / float (waveCount)
        wave_mesh(x, float2(0.0, sh * (1.0 - layerThickness*float(waveCount) + layerThickness*float(i))),
                     make_color(0.85+0.15*k), 100, sw, sh*layerThickness*3.0)

    //////////////////////////
    // GAMEPLAY MECHANICS
    //////////////////////////
    
    //// ENEMIES
    enemyTypes |> resize(5)
    // small enemy ship
    enemyTypes[0].startHealth = 0.2
    enemyTypes[0].health = enemyTypes[0].startHealth
    enemyTypes[0].size = float2(0.03, 0.015)
    enemyTypes[0].color = float4(0.5, 0.1, 0.1, 1.0)
    enemyTypes[0].colorLights = float4(0.1, 1.0, 0.1, 1.0)
    enemyTypes[0].weaponReloadSpeed = float4(0.5, 0.0, 0.0, 0.0)
    enemyTypes[0].weapon = int4(2, -1, -1, -1)
    enemyTypes[0].speed = 0.2
    enemyTypes[0].deathState = 2
    enemyTypes[0].deathWaterSplash = 3
    enemyTypes[0].angle = 0.0
    enemyTypes[0].fireEffect = 4
    enemyTypes[0].score = 10
    // mid enemy ship
    enemyTypes[1].startHealth = 0.8
    enemyTypes[1].health = enemyTypes[1].startHealth
    enemyTypes[1].size = float2(0.06, 0.04)
    enemyTypes[1].color = float4(0.5, 0.8, 0.1, 1.0)
    enemyTypes[1].colorLights = float4(1.0, 1.0, 0.0, 1.0)
    enemyTypes[1].weaponReloadSpeed = float4(1.0, 0.2, 0.0, 0.0)
    enemyTypes[1].weapon = int4(0, 1, -1, -1)
    enemyTypes[1].speed = 0.1
    enemyTypes[1].deathState = 2
    enemyTypes[1].deathWaterSplash = 1
    enemyTypes[1].angle = 0.0
    enemyTypes[1].fireEffect = 5
    enemyTypes[1].score = 40
    // corsair
    enemyTypes[2].startHealth = 0.4
    enemyTypes[2].health = enemyTypes[2].startHealth
    enemyTypes[2].size = float2(0.04, 0.02)
    enemyTypes[2].color = float4(0.1, 0.6, 0.8, 1.0)
    enemyTypes[2].colorLights = float4(1.0, 0.0, 0.0, 1.0)
    enemyTypes[2].weaponReloadSpeed = float4(0.75, 0.0, 0.4, 0.0)
    enemyTypes[2].weapon = int4(3, -1, 0, -1)
    enemyTypes[2].speed = 0.3
    enemyTypes[2].deathState = 2
    enemyTypes[2].deathWaterSplash = 3
    enemyTypes[2].angle = 0.0
    enemyTypes[2].fireEffect = 4
    enemyTypes[2].score = 80
    // large enemy ship
    enemyTypes[3].startHealth = 2.0
    enemyTypes[3].health = enemyTypes[3].startHealth
    enemyTypes[3].size = float2(0.09, 0.05)
    enemyTypes[3].color = float4(1.0, 0.0, 0.0, 1.0)
    enemyTypes[3].colorLights = float4(0.0, 0.0, 1.0, 1.0)
    enemyTypes[3].weaponReloadSpeed = float4(0.5, 0.1, 0.0, 0.0)
    enemyTypes[3].weapon = int4(1, 4, -1, -1)
    enemyTypes[3].speed = 0.1
    enemyTypes[3].deathState = 2
    enemyTypes[3].deathWaterSplash = 4
    enemyTypes[3].angle = 0.0
    enemyTypes[3].fireEffect = 5
    enemyTypes[3].score = 100
    // elite enemy ship
    enemyTypes[4].startHealth = 2.0
    enemyTypes[4].health = enemyTypes[3].startHealth
    enemyTypes[4].size = float2(0.06, 0.02)
    enemyTypes[4].color = float4(0.0, 0.0, 0.5, 1.0)
    enemyTypes[4].colorLights = float4(0.0, 1.0, 1.0, 1.0)
    enemyTypes[4].weaponReloadSpeed = float4(2.0, 0.05, 0.2, 0.0)
    enemyTypes[4].weapon = int4(0, 4, 3, -1)
    enemyTypes[4].speed = 0.4
    enemyTypes[4].deathState = 2
    enemyTypes[4].deathWaterSplash = 1
    enemyTypes[4].angle = 0.0
    enemyTypes[4].fireEffect = 6
    enemyTypes[4].score = 150

    //// ENEMY WEAPONS
    enemyBulletTypes |> resize(5)
    // small enemy bullet
    enemyBulletTypes[0].maxSpeed = 0.7
    enemyBulletTypes[0].damage = 0.01
    enemyBulletTypes[0].explosionType = 0
    enemyBulletTypes[0].visual = 0
    enemyBulletTypes[0].size = 0.0
    // small depth charge
    enemyBulletTypes[1].maxSpeed = 0.3
    enemyBulletTypes[1].damage = 0.1
    enemyBulletTypes[1].explosionType = 1
    enemyBulletTypes[1].visual = 1
    enemyBulletTypes[1].size = 0.02
    // large enemy bullet
    enemyBulletTypes[2].maxSpeed = 0.4
    enemyBulletTypes[2].damage = 0.05
    enemyBulletTypes[2].explosionType = 2
    enemyBulletTypes[2].visual = 3
    enemyBulletTypes[2].size = 0.005
    // corsair torpedo
    enemyBulletTypes[3].maxSpeed = 0.5
    enemyBulletTypes[3].damage = 0.1
    enemyBulletTypes[3].explosionType = 3
    enemyBulletTypes[3].visual = 2
    enemyBulletTypes[3].size = 0.02
    // devastating depth charge
    enemyBulletTypes[4].maxSpeed = 0.2
    enemyBulletTypes[4].damage = 0.5
    enemyBulletTypes[4].explosionType = 4
    enemyBulletTypes[4].visual = 6
    enemyBulletTypes[4].size = 0.07

    //// PLAYER WEAPONS
    playerBulletTypes |> resize(4)
    // small player bullet
    playerBulletTypes[0].maxSpeed = 0.7
    playerBulletTypes[0].damage = 0.1
    playerBulletTypes[0].visual = 2

    //// WATER EXPLOSIONS
    waterExplosionTypes |> resize(5)
    // empty explosion
    waterExplosionTypes[0].strength = 0.0
    waterExplosionTypes[0].curTime = 0.0
    waterExplosionTypes[0].fadeMul = 1000.0
    waterExplosionTypes[0].radMul = 0.0
    waterExplosionTypes[0].visualSize = float2(0.01, 0.03)
    waterExplosionTypes[0].visualLifetime = 0.4
    // depth charge explosion
    waterExplosionTypes[1].strength = 0.05
    waterExplosionTypes[1].curTime = 0.0
    waterExplosionTypes[1].fadeMul = 0.3
    waterExplosionTypes[1].radMul = 0.07
    waterExplosionTypes[1].visualSize = float2(0.05, 0.1)
    waterExplosionTypes[1].visualLifetime = 1.0
    // large bullet explosion
    waterExplosionTypes[2].strength = 0.03
    waterExplosionTypes[2].curTime = 0.0
    waterExplosionTypes[2].fadeMul = 0.5
    waterExplosionTypes[2].radMul = 0.05
    waterExplosionTypes[2].visualSize = float2(0.02, 0.04)
    waterExplosionTypes[2].visualLifetime = 0.6
    // corsair torpedo explosion
    waterExplosionTypes[3].strength = 0.05
    waterExplosionTypes[3].curTime = 0.0
    waterExplosionTypes[3].fadeMul = 0.6
    waterExplosionTypes[3].radMul = 0.06
    waterExplosionTypes[3].visualSize = float2(0.04, 0.08)
    waterExplosionTypes[3].visualLifetime = 0.8
    // large charge explosion
    waterExplosionTypes[4].strength = 0.1
    waterExplosionTypes[4].curTime = 0.0
    waterExplosionTypes[4].fadeMul = 0.3
    waterExplosionTypes[4].radMul = 0.08
    waterExplosionTypes[4].visualSize = float2(0.1, 0.2)
    waterExplosionTypes[4].visualLifetime = 3.0

    //////////////////////////
    // VISUAL EFFECTS
    //////////////////////////
    bulletVisuals |> resize(7)
    // small enemy bullet
    bulletVisuals[0].size = 10.0
    bulletVisuals[0].count = 3
    bulletVisuals[0].trace = 0.1
    bulletVisuals[0].part = 0
    bulletVisuals[0].color0 = float4(1.0, 0.0, 0.0, 1.0)
    bulletVisuals[0].color1 = float4(1.0, 0.5, 0.0, 1.0)
    // small depth charge
    bulletVisuals[1].size = 22.0
    bulletVisuals[1].count = 10
    bulletVisuals[1].trace = 0.2
    bulletVisuals[1].part = 1
    bulletVisuals[1].color0 = float4(1.0, 1.0, 0.0, 1.0)
    bulletVisuals[1].color1 = float4(4.0, 0.0, 0.0, 0.7)
    // small player bullet
    bulletVisuals[2].size = 15.0
    bulletVisuals[2].count = 4
    bulletVisuals[2].trace = 0.07
    bulletVisuals[2].part = 0
    bulletVisuals[2].color0 = float4(0.0, 1.0, 0.0, 1.0)
    bulletVisuals[2].color1 = float4(0.0, 1.0, 2.0, 1.0)
    // large enemy bullet
    bulletVisuals[3].size = 10.0
    bulletVisuals[3].count = 6
    bulletVisuals[3].trace = 0.2
    bulletVisuals[3].part = 0
    bulletVisuals[3].color0 = float4(1.0, 0.0, 1.0, 1.0)
    bulletVisuals[3].color1 = float4(0.0, 0.0, 4.0, 1.0)
    // small fire
    bulletVisuals[4].size = 30.0
    bulletVisuals[4].count = 10
    bulletVisuals[4].trace = 0.4
    bulletVisuals[4].part = 2
    bulletVisuals[4].color0 = float4(1.0, 0.5, 0.0, 1.0)
    bulletVisuals[4].color1 = float4(0.5, 0.0, 0.0, 0.7)
    // large fire
    bulletVisuals[5].size = 60.0
    bulletVisuals[5].count = 10
    bulletVisuals[5].trace = 0.4
    bulletVisuals[5].part = 2
    bulletVisuals[5].color0 = float4(1.0, 1.0, 0.0, 1.0)
    bulletVisuals[5].color1 = float4(4.0, 0.0, 0.0, 0.7)
    // devastating depth charge
    bulletVisuals[6].size = 32.0
    bulletVisuals[6].count = 20
    bulletVisuals[6].trace = 0.8
    bulletVisuals[6].part = 1
    bulletVisuals[6].color0 = float4(1.0, 0.0, 1.0, 1.0)
    bulletVisuals[6].color1 = float4(0.0, 2.0, 2.0, 1.0)


    reset_game()

def gameSimulation(dt: float)

    // simulate enemy spawning
    let maxEnemiesAlive = 20
    let maximumLevel = 4.99
    let maxLevelMultiplier = 20.0
    enemyMaxLevel = min(log(1.0 + float(totalScore)/maxLevelMultiplier), maximumLevel)
    var enemyMinLevel = 0.0
    let maxLevelScore = (exp(maximumLevel) - 1.0)*maxLevelMultiplier;
    if (enemyMaxLevel >= maximumLevel)
        enemyMinLevel = min(log(1.0 + max(0.0, float(totalScore) - maxLevelScore)/maxLevelMultiplier), maximumLevel)
    explAdd += dt
    if (explAdd > 2.3 && aliveEnemyCount < maxEnemiesAlive)
        addTypedEnemy(int(rnd(enemyMinLevel, enemyMaxLevel)), rnd(0.0, 3.1415), rnd(0.1, 0.45))
        explAdd = 0.0;
    let enemyAmplitude = 0.45

    var scoreDelta = 0
    aliveEnemyCount = 0

    // simulate enemies
    for x in enemies
        if (x.health<=0.0)
            if (x.deathState < 0) // absolutely dead and ready to rebirth
                continue
            if (x.deathState == 2) // died last frame
                scoreDelta += x.score
                x.phase = enemyAmplitude * x.speed * cos(x.phase) // current horisontal velocity
                x.speed = 0.0
                x.deathState = 1
            if (x.deathState == 1) // falling down to sea
                x.speed += 0.1*dt
                x.coord += dt*float2(x.phase, x.speed)
                x.angle += 0.1*dt
                if (x.coord.y> 1.0 - seaLevel - 0.5*min(x.size.x, x.size.y))
                    x.deathState = 0
                    addTypedWaterExplosion(x.deathWaterSplash, float2(x.coord.x, 1.0))
            if (x.deathState == 0) // sunking in sea
                x.speed = min(0.025, x.speed + 0.1*dt)
                x.coord += dt*float2(x.phase*0.1, x.speed)
                x.angle += 0.1*dt
                if (x.coord.y > 1.0 - seaLevel + max(x.size.x, x.size.y))
                    x.deathState = -1 // totally sunked
            continue
        aliveEnemyCount += 1
        x.phase += dt*x.speed
        x.coord.x = 0.5+enemyAmplitude*sin(x.phase)
        x.weaponReload += dt * x.weaponReloadSpeed
        if (x.weaponReload.x > 1.0) // main gun, pointing at player
            addTypedEnemyBullet(x.weapon.x, x.coord, player.coord)
            x.weaponReload.x = 0.0
        if (x.weaponReload.y > 1.0) // like depth charge, fall at y coord of layer
            addTypedEnemyBullet(x.weapon.y, x.coord, float2(x.coord.x, player.coord.y))
            x.weaponReload.y = 0.0
        if (x.weaponReload.z > 1.0) // burst of 4 charges at time
            for i in range(4)
                addTypedEnemyBullet(x.weapon.z, x.coord, 0.1*float2(rnd(-0.5, 0.5), rnd(-0.5, 0.5)) + player.coord)
            x.weaponReload.z = 0.0

    // simulate enemy bullets
    for x in enemyBullets
        if x.damage <= 0.0
            continue
        x.coord += x.speed * dt
        if (x.coord.y > 1.0 - seaLevel*x.target.y)
            addTypedWaterExplosion(x.explosionType, x.target)
            // calculate collision with player
            if (length(x.target - player.coord)<= player.size + x.size)
                player.health -= x.damage
            x.damage = -1.0

    // simulate player bullets
    for x in playerBullets
        if x.damage <= 0.0
            continue
        x.coord += x.speed * dt
        if (x.coord.x > 1.0 || x.coord.y > 1.0 || x.coord.x < 0.0 || x.coord.y < 0.0)
            x.damage = -1.0
            continue
        // calculate collision with enemy ships
        for eShip in enemies
            if (eShip.health<=0.0)
                continue
            if (abs(eShip.coord.x - x.coord.x) - x.size < 0.5*eShip.size.x && abs(eShip.coord.y - x.coord.y) - x.size < 0.5*eShip.size.y)
                eShip.health -= x.damage
                x.damage = -1.0
                break
            

    // simulate waterExplosions
    for x in waterExplosions
        if x.strength < 0.0
            continue
        x.curTime += dt
        x.curStrength = min(x.curTime*10.0, 1.0)*(x.strength * exp(-x.fadeMul*x.curTime) - 0.01)
        x.rad = 0.005 + x.curTime * x.radMul
        x.coord.y -= 0.01*dt

        if (x.curStrength < 0.0 && x.curTime > x.visualLifetime)
            x.strength = -1.0

    // simulate player
    player.speed *= exp(-4.0*dt)

    if get_key(VK_LEFT)
        player.speed.x = -0.15 
    if get_key(VK_RIGHT)
        player.speed.x = 0.15
    if get_key(VK_UP)
        player.speed.y = 0.15
    if get_key(VK_DOWN)
        player.speed.y = -0.15

    player.coord.x = clamp(player.coord.x + player.speed.x * dt, 0.000001, 0.999999)
    player.coord.y = clamp(player.coord.y + player.speed.y * dt, 0.000001, 0.999999)

    var p1 = wave_simulation(float2(player.coord.x - player.size*0.5, player.coord.y))
    var p2 = wave_simulation(float2(player.coord.x + player.size*0.5, player.coord.y))
    player.angle = atan((p1 - p2) / player.size)

    player.weaponReload += 5.0*dt
    if (get_key(VK_SPACE) && player.weaponReload >= 1.0)
        addTypedPlayerBullet(0, player.angle)
        player.weaponReload = 0.0


    totalScore += scoreDelta
    healthRegain += scoreDelta
    if (healthRegain >= 100)
        player.health  = min(1.0, player.health + 0.1)
        healthRegain -= 100

    //player.health  = 1.0

    if (player.health <= 0.0)
        reset_game()

[export]
def act(dt: float)
    if (gameStarted)
        gameSimulation(dt)
    
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    gameDelay -= dt
    if get_key(VK_SPACE) && gameDelay <= 0.0
        gameStarted = true

def render_bullet_visual(vtype: int; bpos: float2; speed: float2)
    let sw = globalSw
    let sh = globalSh
    let num = bulletVisuals[vtype].count + 1
    if (particles[bulletVisuals[vtype].part].ablendMode == 0)
        enable_alpha_blend()
    else
        enable_premultiplied_alpha_blend()
    for i in range(num)
        let k = float(i) / float(num)

        let pos = (bpos - k*speed*bulletVisuals[vtype].trace) * float2(sw, sh)
        let sz = bulletVisuals[vtype].size * (1.0 - k)

        var st = 10.0*get_time_after_start() + 10.0*k
        let vecx = float2(sz * 0.5 * cos(st), sz * 0.5 * sin(st))
        let vecy = float2(-sz * 0.5 * sin(st), sz * 0.5 * cos(st))
        particles[bulletVisuals[vtype].part].bmap |> draw_quad(pos - vecx - vecy,
                                                               pos + vecx - vecy,
                                                               pos + vecx + vecy,
                                                               pos - vecx + vecy,
                                                               make_color(bulletVisuals[vtype].color0 * (1.0 - k) + bulletVisuals[vtype].color1 * k))
    disable_alpha_blend()


def render_enemy_visual(enemy: Enemy)
    let sw = globalSw
    let sh = globalSh

    // fire effect behind ship
    if enemy.deathState == 1
        render_bullet_visual(enemy.fireEffect, enemy.coord, float2(enemy.phase, enemy.speed))

    enable_alpha_blend()

    var pos = enemy.coord * float2(sw, sh)
    var sz = enemy.size * float2(sw, sh)

    var st = enemy.angle
    var vecx = float2(sz.x * 0.5 * cos(st), sz.x * 0.5 * sin(st))
    var vecy = float2(-sz.y * 0.5 * sin(st), sz.y * 0.5 * cos(st))
    enemy_ship[0] |> draw_quad(pos - vecx - vecy,
                                pos + vecx - vecy,
                                pos + vecx + vecy,
                                pos - vecx + vecy,
                                make_color(enemy.color))
    
    let colorMul = enemy.health / enemy.startHealth

    if (colorMul < 1.0)
        enemy_ship[1] |> draw_quad(pos - vecx - vecy,
                                    pos + vecx - vecy,
                                    pos + vecx + vecy,
                                    pos - vecx + vecy,
                                    make_color(1.0, 1.0 - colorMul))

    // fire effect behind ship
    if enemy.deathState == 1
        render_bullet_visual(enemy.fireEffect, enemy.coord, float2(enemy.phase, enemy.speed))

    if enemy.health <= 0.0
        disable_alpha_blend()
        return
        

    enable_premultiplied_alpha_blend()
    let lights_count = 3
    var sz1 = max(sz.x, sz.y)*0.15

    for i in range(-lights_count, lights_count+1)
        let k = float(i) / float(lights_count)

        let posL = pos + float2(sz.x*0.5, 0.0)*k

        let normalWork = colorMul*0.25*(3.0 + sin(10.0*get_time_after_start() + 3.0*k + enemy.phase))
   
        vecx = float2(sz1 * 0.5 * cos(st), sz1 * 0.5 * sin(st))
        vecy = float2(-sz1 * 0.5 * sin(st), sz1 * 0.5 * cos(st))
        particles[0].bmap |> draw_quad( posL - vecx - vecy,
                                        posL + vecx - vecy,
                                        posL + vecx + vecy,
                                        posL - vecx + vecy,
                                        make_color(enemy.colorLights*normalWork))

    disable_alpha_blend()


def draw_water_splashes(wave_range : float2)
    let sw = globalSw
    let sh = globalSh
    enable_premultiplied_alpha_blend()

    for x in waterExplosions
        if x.strength < 0.0
            continue
        if x.curTime > x.visualLifetime || (x.coord.y < wave_range.x) || (x.coord.y >= wave_range.y)
            continue
        let st = sqrt(x.curTime / x.visualLifetime)
        let partCount = 4
        for i in range(partCount)
            let t = (float(i) + 0.5)/float(partCount)
            let sz = float2(sw, sh)*x.visualSize*float2(st, sin(3.1415*st))*float2(t, 1.0-t)
            draw_image(water_splash, x.coord.x*sw - sz.x*0.5, (1.0 - x.coord.y * seaLevel) * sh - sz.y, make_color(min(1.0, 4.0 - 4.0*st)), sz)
    disable_alpha_blend()

[export]
def draw
    sky_gradient |> draw_image(0.0, 0.0, make_color(1.0),
        float2(get_screen_width(), get_screen_height()))

    let t = get_time_after_start()

    globalSw = float(get_screen_width())
    globalSh = float(get_screen_height())

    let sw = globalSw
    let sh = globalSh

    // render dead enemies
    for x in enemies
        if (x.deathState < 0 || x.deathState == 2)
            continue
        render_enemy_visual(x)

    // render water waves
    for x, i in waves, range(1000)
        let tmpH = 1.0 - float(i) / float(waveCount)
        for j in range(x.count)
            let tmpW = float(j) / float(x.count)
            var delta = -0.5*1.25*(4.0 + sin(t + 17.0*tmpH) + sin(3.0*t + 15.0*tmpW) + sin(2.0*t + 10.5*(tmpW + tmpH)) + sin(2.0*t + 20.0*(tmpW - tmpH)))
            delta -= wave_simulation(float2(tmpW, tmpH))*sh
            x.coord[2*j+1].y = x.coord[2*j].y + delta - sh*layerThickness*3.0;
            x.uv[2*j+1].y = 1.0 + min(0.1*abs(delta), 2.0)

        sea_wave_gradient |> draw_triangle_strip(x.coord, x.uv, x.color)

        var wave_range = float2(tmpH - 1.0 / float(waveCount), tmpH)
        if (wave_range.x == 0.0)
            wave_range.x = -1.0 // lowest line is "endless"

        // render player's ship
        enable_alpha_blend()
        if player.coord.y >= wave_range.x && player.coord.y < wave_range.y
            let sz = player.size * 0.5 * float2(sw, sh)
            let st = player.angle
            var vecx = float2(sz.x * cos(st), sz.x * sin(st))
            var vecy = float2(-sz.y * sin(st), sz.y * cos(st))
            var pos = float2(player.coord.x * sw, (1.0 - player.coord.y * seaLevel) * sh)
            player_ship |> draw_quad(pos - vecx - vecy,
                                    pos + vecx - vecy,
                                    pos + vecx + vecy,
                                    pos - vecx + vecy, make_color(1.0, 1.0, 1.0))
            pos -= vecy
            vecy *= -0.5
            vecx *= 0.5
            player_ship |> draw_quad(pos - vecx - vecy,
                                    pos + vecx - vecy,
                                    pos + vecx + vecy,
                                    pos - vecx + vecy, make_color(1.0, 1.0, 1.0))
            //line(pos.x, pos.y, pos.x + sh * sin(st), pos.y - sh * cos(st), make_color(1.0, 0.0, 0.0))
        disable_alpha_blend()
        
        // render splashes between waves
        draw_water_splashes(wave_range)
    
    // render enemy bullets
    for x in enemyBullets
        if x.damage <= 0.0
            continue
        render_bullet_visual(x.visual, x.coord, x.speed)

    // render player bullets
    for x in playerBullets
        if x.damage <= 0.0
            continue
        render_bullet_visual(x.visual, x.coord, x.speed)

    // render alive enemies
    for x in enemies
        if (x.deathState < 2)
            continue
        render_enemy_visual(x)


    if true
        // render HUD
        var hudOfs = 40.0
        var hudLine = 20.0
        let hudOfsX = 10.0
        var healthInt = int(player.health * 100.0)
        var healthInfo = "Health {healthInt}"
        text_out(hudOfsX, hudOfs, healthInfo, make_color(0.5, 0.0, 0.0))
        hudOfs += hudLine
        
        var scoreInfo  = "Score: {totalScore}    MaximumScore: {maxScore}"
        text_out(hudOfsX, hudOfs, scoreInfo, make_color(0.0, 0.5, 0.0))
        hudOfs += hudLine

        var healthRegainInfo  = "Health regain: {healthRegain} from 100"
        text_out(hudOfsX, hudOfs, healthRegainInfo, make_color(0.5, 0.5, 0.0))
        hudOfs += hudLine

        var enemyLevelInfo  = "Maximum enemy level: {int(enemyMaxLevel + 1.0)}"
        text_out(hudOfsX, hudOfs, enemyLevelInfo, make_color(0.0, 0.0, 0.5))
        hudOfs += hudLine
    if !gameStarted // render game info
        var hudOfs = 80.0
        var hudLine = 20.0
        let hudOfsX = 350.0
        text_out(hudOfsX, hudOfs, "Welcome to Sea Invaders!", make_color(0.5, 0.0, 0.0))
        hudOfs += 2.0*hudLine
        text_out(hudOfsX, hudOfs, "It's almost like Space Invaders, but much worse.", make_color(0.5, 0.0, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "You controlling last Earth's naval warship and fighting", make_color(0.5, 0.0, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "against endless enemy invasion. Endless, yes.", make_color(0.5, 0.0, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "So let their's mothers cry, cuz you purpose is to kill xeno scum", make_color(0.5, 0.0, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "Use arrow keys to move your ship", make_color(1.0, 1.0, 1.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "You can move up and down too! Game is full 3D", make_color(0.0, 0.5, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "Sea waves make your ship shaking, so better to avoid them", make_color(0.0, 0.5, 0.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "Press SPACE to fire your weapon", make_color(1.0, 1.0, 1.0))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "Kill enemy space ships to gain score", make_color(0.5, 0.0, 0.5))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "Every 100 points will regain you 10 points of health", make_color(0.5, 0.0, 0.5))
        hudOfs += hudLine
        text_out(hudOfsX, hudOfs, "More score - more advanced and dangerous enemy, so be prepared!", make_color(0.0, 0.0, 0.0))
        hudOfs += 2.0*hudLine
        text_out(hudOfsX, hudOfs, "PRESS 'SPACE' TO START THE MASSACRE", make_color(1.0, 1.0, 1.0))