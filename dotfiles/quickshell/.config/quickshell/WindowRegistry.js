.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    if (mw <= 0 || mh <= 0) return 1.0;
    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);
    let baseScale = 1.0;
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);

    let base = {
        "controlcenter": { w: s(420, scale), h: mh - s(80, scale), rx: mw - s(440, scale), ry: s(40, scale) },
        "music":         { w: s(680, scale), h: s(600, scale), rx: s(20, scale), ry: s(60, scale) },
        "wallpaper":     { w: mw - s(40, scale), h: s(500, scale), rx: s(20, scale), ry: Math.floor((mh - s(500, scale)) / 2) },
        "network":       { w: s(380, scale), h: s(480, scale), rx: mw - s(400, scale), ry: s(60, scale) },
        "statusmonitor": { w: s(520, scale), h: s(600, scale), rx: Math.floor((mw - s(520, scale)) / 2), ry: s(60, scale) },
        "monitor":       { w: s(360, scale), h: s(320, scale), rx: mw - s(380, scale), ry: s(60, scale) },
        "dashboard":     { w: s(600, scale), h: s(500, scale), rx: Math.floor((mw - s(600, scale)) / 2), ry: Math.floor((mh - s(500, scale)) / 2) },
        "hidden":        { w: 1, h: 1, rx: -5000, ry: -5000 }
    };

    if (!base[name]) return null;
    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    return t;
}
