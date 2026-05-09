let vehicles = [];
let garages = {};
let coords = null;
let store = null;
let spawn = null;
let resource = 'ug_garage';
let jobVehicles = [];
let selectedJobGarageId = null;
let garageTab = 'vehicles';
let currentGarageIsJob = false;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then(async r => {
        try { return await r.json(); } catch (_) { return {}; }
    });
}

function show(view) {
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('garageView').classList.toggle('hidden', view !== 'garage');
    document.getElementById('adminView').classList.toggle('hidden', view !== 'admin');
}

function closeUi(event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    const app = document.getElementById('app');
    if (app) app.classList.add('hidden');
    post('close').catch(() => {});
}
window.closeUi = closeUi;

function showNotification(data = {}) {
    const container = document.getElementById('toastContainer');
    const type = normalizeType(data.type || 'inform');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <div class="toast-bar"></div>
        <div class="toast-content">
            <div class="toast-title">${escapeHtml(data.title || t('garage'))}</div>
            <div class="toast-message">${escapeHtml(data.message || '')}</div>
        </div>
    `;
    container.appendChild(toast);
    setTimeout(() => {
        toast.classList.add('hide');
        setTimeout(() => toast.remove(), 220);
    }, data.duration || 4300);
}

function normalizeType(type) {
    if (type === 'success') return 'success';
    if (type === 'error') return 'error';
    if (type === 'warn') return 'warning';
    if (type === 'warning') return 'warning';
    return 'inform';
}

function garageTypeLabel(type) {
    if (type === 'air') return t('air');
    if (type === 'boat') return t('boats');
    return t('cars');
}

function renderVehicleStats(filteredCount = null) {
    const total = filteredCount === null ? vehicles.length : filteredCount;
    const ready = vehicles.filter(v => v.stored).length;
    const out = vehicles.filter(v => !v.stored).length;
    const garageType = window.currentGarageData?.vehicleType || 'car';
    const set = (id, value) => { const el = document.getElementById(id); if (el) el.innerText = value; };
    set('statTotal', total);
    set('statReady', ready);
    set('statOut', out);
    set('statType', garageTypeLabel(garageType));
    const kicker = document.getElementById('garageTypeKicker');
    if (kicker) kicker.innerText = `// ${garageTypeLabel(garageType).toUpperCase()}`;
}

function renderVehicles() {
    const list = document.getElementById('vehicleList');
    const q = document.getElementById('vehicleSearch').value.toLowerCase();
    list.innerHTML = '';

    const filtered = vehicles.filter(v => `${v.plate} ${v.model} ${v.displayName} ${v.make} ${v.className}`.toLowerCase().includes(q));
    renderVehicleStats(filtered.length);
    if (!filtered.length) {
        list.innerHTML = `<div class="vehicle empty"><div><div class="vehicle-placeholder"><b>🚗</b></div><strong>${t('noVehiclesFound')}</strong><div class="meta">${t('noVehiclesFoundMeta')}</div></div></div>`;
        return;
    }

    filtered.forEach(v => {
        const el = document.createElement('div');
        el.className = 'vehicle neon-card';
        const engineRaw = percentNumber(v.engineHealth);
        const bodyRaw = percentNumber(v.bodyHealth);
        const fuelRaw = Number.isFinite(Number(v.fuel)) ? Math.max(0, Math.min(100, Number(v.fuel))) : null;
        const engine = healthPercent(v.engineHealth);
        const body = healthPercent(v.bodyHealth);
        const fuel = fuelRaw === null ? t('unknown') : `${Math.round(fuelRaw)}%`;
        const img = v.image ? `<img src="${v.image}" alt="${escapeHtml(v.displayName || t('vehicle'))}" />` : `<div class="vehicle-placeholder"><div><b>🚘</b><span>${t('imageCreating')}</span></div></div>`;
        const isJob = !!v.jobVehicleId;
        el.innerHTML = `
            <div class="vehicle-image" data-model-key="${escapeHtml(v.imageKey || '')}">
                <span class="favorite">★ ${isJob ? t('jobVehicle') : t('vehicle')}</span>
                ${img}
            </div>
            <div class="vehicle-content">
                <div class="vehicle-head">
                    <div class="vehicle-title">
                        <strong>${escapeHtml(v.displayName || v.model || t('unknownVehicle'))}</strong>
                        <small>${escapeHtml(v.plate || (isJob ? t('jobVehicle') : t('noPlate')))} · ${escapeHtml(v.make || t('unknownMake'))} · ${escapeHtml(v.className || t('unknownClass'))}</small>
                    </div>
                    <div>
                        <span class="badge ${v.stored ? 'success' : 'warn'}">${v.stored ? t('ready') : t('out')}</span>
                        ${isJob ? '<span class="badge job" style="margin-top:6px">Job</span>' : ''}
                    </div>
                </div>

                <div class="vehicle-stats">
                    <div class="stat"><span>${t('fuel')}</span><strong>${fuel}</strong><div class="meter"><i style="width:${fuelRaw === null ? 0 : fuelRaw}%"></i></div></div>
                    <div class="stat"><span>${t('engine')}</span><strong>${engine}</strong><div class="meter"><i style="width:${engineRaw === null ? 0 : engineRaw}%"></i></div></div>
                    <div class="stat"><span>${t('body')}</span><strong>${body}</strong><div class="meter"><i style="width:${bodyRaw === null ? 0 : bodyRaw}%"></i></div></div>
                </div>

                ${renderVehicleColors(v)}

                <details class="vehicle-details">
                    <summary>${t('moreInfo')}</summary>
                    <div class="info-grid">
                        <div class="info"><span>${t('garage')}</span><b>${escapeHtml(v.garage || t('unknown'))}</b></div>
                        <div class="info"><span>${t('modelHash')}</span><b>${escapeHtml(v.modelHash || v.model || t('unknown'))}</b></div>
                        <div class="info"><span>${t('mileage')}</span><b>${numberOrUnknown(v.mileage)}</b></div>
                        <div class="info"><span>${t('dirt')}</span><b>${numberOrUnknown(v.dirtLevel)}</b></div>
                        <div class="info"><span>${t('tankHealth')}</span><b>${numberOrUnknown(v.tankHealth)}</b></div>
                        <div class="info"><span>${t('mods')}</span><b>${Number.isFinite(Number(v.modsCount)) ? v.modsCount : 0}</b></div>
                        <div class="info"><span>${t('depotPrice')}</span><b>${moneyOrUnknown(v.depotPrice)}</b></div>
                        <div class="info"><span>${t('financing')}</span><b>${moneyOrUnknown(v.balance || v.paymentAmount)}</b></div>
                        <div class="info"><span>${t('primaryRgb')}</span><b>${rgbText(v.primaryRgb)}</b></div>
                        <div class="info"><span>${t('secondaryRgb')}</span><b>${rgbText(v.secondaryRgb)}</b></div>
                        <div class="info"><span>${t('color12')}</span><b>${valueOrUnknown(v.color1)} / ${valueOrUnknown(v.color2)}</b></div>
                        <div class="info"><span>${t('pearlWheel')}</span><b>${valueOrUnknown(v.pearlescentColor)} / ${valueOrUnknown(v.wheelColor)}</b></div>
                        <div class="info"><span>${t('windowTint')}</span><b>${valueOrUnknown(v.windowTint)}</b></div>
                        <div class="info"><span>${t('livery')}</span><b>${valueOrUnknown(v.livery)}</b></div>
                    </div>
                </details>

                <div class="vehicle-actions">
                    ${v.impounded
                        ? `<button onclick="spawnImpoundVehicle('${escapeJs(v.plate || '')}', '${escapeJs(String(v.model || ''))}')">${t('recoverImpound')}${v.impoundFee ? ` · $${Number(v.impoundFee).toLocaleString('de-DE')}` : ''}</button>`
                        : `<button ${v.stored ? '' : 'disabled'} onclick="spawnVehicle('${escapeJs(v.plate || '')}', '${escapeJs(String(v.model || ''))}', ${v.jobVehicleId ? Number(v.jobVehicleId) : 'null'})">${t('spawn')}</button>`}
                </div>
            </div>
        `;
        list.appendChild(el);
    });
}

function percentNumber(value) {
    const n = Number(value);
    if (!Number.isFinite(n) || n <= 0) return null;
    return Math.max(0, Math.min(100, Math.round(n / 10)));
}


function rgbText(rgb) {
    if (!rgb) return t('unknown');
    return `${Number(rgb.r || 0)}, ${Number(rgb.g || 0)}, ${Number(rgb.b || 0)}`;
}

function rgbCss(rgb) {
    if (!rgb) return 'transparent';
    return `rgb(${Number(rgb.r || 0)}, ${Number(rgb.g || 0)}, ${Number(rgb.b || 0)})`;
}

function renderVehicleColors(v) {
    if (!v.primaryRgb && !v.secondaryRgb) return '';
    return `
        <div class="vehicle-colors">
            <div class="color-pill"><i style="background:${rgbCss(v.primaryRgb)}"></i><span>${t('primary')} ${rgbText(v.primaryRgb)}</span></div>
            <div class="color-pill"><i style="background:${rgbCss(v.secondaryRgb)}"></i><span>${t('secondary')} ${rgbText(v.secondaryRgb)}</span></div>
        </div>
    `;
}

function setVehicleImage(modelKey, image) {
    vehicles = vehicles.map(v => String(v.imageKey) === String(modelKey) ? { ...v, image } : v);
    document.querySelectorAll(`.vehicle-image[data-model-key="${cssEscape(String(modelKey))}"]`).forEach(el => {
        const vehicle = vehicles.find(v => String(v.imageKey) === String(modelKey));
        const alt = escapeHtml(vehicle?.displayName || t('vehicle'));
        el.innerHTML = `<img src="${image}" alt="${alt}" />`;
    });
}

function cssEscape(value) {
    if (window.CSS && CSS.escape) return CSS.escape(value);
    return value.replace(/[^a-zA-Z0-9_-]/g, '\\$&');
}

function healthPercent(value) {
    const n = Number(value);
    if (!Number.isFinite(n) || n <= 0) return t('unknown');
    return `${Math.max(0, Math.min(100, Math.round(n / 10)))}%`;
}

function numberOrUnknown(value, suffix = '') {
    const n = Number(value);
    if (!Number.isFinite(n)) return t('unknown');
    return `${Math.round(n * 10) / 10}${suffix}`;
}

function moneyOrUnknown(value) {
    const n = Number(value);
    if (!Number.isFinite(n) || n === 0) return t('notAvailable');
    return `$${Math.round(n).toLocaleString('de-DE')}`;
}

function valueOrUnknown(value) {
    if (value === null || value === undefined || value === '') return t('unknown');
    if (typeof value === 'object') return escapeHtml(JSON.stringify(value));
    return escapeHtml(String(value));
}

function setGarageTab(tab) {
    if (tab === 'impound' && currentGarageIsJob) {
        showNotification({ type: 'warning', message: t('impoundPublicOnly') });
        tab = 'vehicles';
    }
    garageTab = tab === 'impound' ? 'impound' : 'vehicles';
    document.getElementById('garageTabVehicles')?.classList.toggle('active', garageTab === 'vehicles');
    document.getElementById('garageTabImpound')?.classList.toggle('active', garageTab === 'impound');
    document.getElementById('garageTypeKicker').innerText = garageTab === 'impound' ? `// ${t('impound').toUpperCase()}` : `// ${t('garage').toUpperCase()}`;
    const endpoint = garageTab === 'impound' ? 'refreshImpoundVehicles' : 'refreshVehicles';
    post(endpoint).then(res => {
        vehicles = res.vehicles || [];
        renderVehicles();
    });
}

function spawnVehicle(plate, model, jobVehicleId = null) {
    post('spawnVehicle', { plate, model, jobVehicleId });
}

function spawnImpoundVehicle(plate, model) {
    post('spawnVehicle', { plate, model, impound: true });
}

function storeCurrentVehicle() {
    post('storeCurrentVehicle').then(() => post(garageTab === 'impound' ? 'refreshImpoundVehicles' : 'refreshVehicles')).then(res => {
        vehicles = res.vehicles || [];
        renderVehicles();
    });
}

let adminTab = 'public';
let jobSubTab = 'vehicles';

function setAdminPage(page) {
    const vehiclePage = page === 'jobVehicles';
    document.getElementById('garageFormCard')?.classList.toggle('hidden', vehiclePage);
    document.querySelector('.admin-tabs')?.classList.toggle('hidden', vehiclePage);
    document.getElementById('publicGaragePanel')?.classList.toggle('hidden', vehiclePage || adminTab !== 'public');
    document.getElementById('jobGaragePanel')?.classList.toggle('hidden', vehiclePage || adminTab !== 'job');
    document.getElementById('jobGarageWorkspace')?.classList.toggle('hidden', !vehiclePage);
}

function setAdminTab(tab) {
    adminTab = tab === 'job' ? 'job' : 'public';
    document.getElementById('tabPublic')?.classList.toggle('active', adminTab === 'public');
    document.getElementById('tabJob')?.classList.toggle('active', adminTab === 'job');
    if (adminTab === 'public') {
        document.getElementById('gType').value = 'public';
        selectedJobGarageId = null;
    } else {
        document.getElementById('gType').value = 'job';
    }
    toggleJobField();
    setAdminPage('main');
    renderAdminGarages();
}

function setJobSubTab(tab) {
    jobSubTab = tab === 'edit' ? 'edit' : 'vehicles';
    document.getElementById('jobSubEdit')?.classList.toggle('active', jobSubTab === 'edit');
    document.getElementById('jobSubVehicles')?.classList.toggle('active', jobSubTab === 'vehicles');
    document.getElementById('jobEditInfo')?.classList.toggle('hidden', jobSubTab !== 'edit');
    document.getElementById('jobVehiclesTab')?.classList.toggle('hidden', jobSubTab !== 'vehicles');
}

function toggleJobField() {
    const type = document.getElementById('gType').value;
    document.getElementById('jobField').classList.toggle('hidden', type !== 'job');
    if (type !== 'job') {
        selectedJobGarageId = null;
        showJobWorkspace(false);
    }
}

function newGarageForm() {
    const type = adminTab === 'job' ? 'job' : 'public';
    document.getElementById('gId').value = '';
    document.getElementById('gLabel').value = '';
    document.getElementById('gType').value = type;
    document.getElementById('gJob').value = '';
    document.getElementById('gVehicleType').value = 'car';
    document.getElementById('gBlip').checked = true;
    coords = null;
    store = null;
    spawn = null;
    selectedJobGarageId = null;
    resetJobVehicleForm();
    showJobWorkspace(false);
    toggleJobField();
    updatePositionPreviews();
}

function fmtPos(p) {
    if (!p) return t('notSet');
    return `x: ${Number(p.x).toFixed(2)}\ny: ${Number(p.y).toFixed(2)}\nz: ${Number(p.z).toFixed(2)}\nh: ${Number(p.w || 0).toFixed(2)}`;
}

function useCurrentPosition(target) {
    post('adminUseCurrentPosition').then(pos => {
        if (target === 'coords') coords = pos;
        if (target === 'store') store = pos;
        if (target === 'spawn') spawn = pos;
        updatePositionPreviews();
        showNotification({ type: 'success', title: t('positionSet'), message: t('currentPositionUsed') });
    });
}

function useVehiclePosition(target) {
    post('adminUseVehiclePosition').then(pos => {
        if (target === 'coords') coords = pos;
        if (target === 'store') store = pos;
        if (target === 'spawn') spawn = pos;
        updatePositionPreviews();
        showNotification({ type: 'success', title: t('positionSet'), message: t('vehiclePositionUsed') });
    });
}

function startPlacement(target) {
    const initial = target === 'coords' ? coords : target === 'store' ? store : spawn;
    document.getElementById('app').classList.add('hidden');
    showNotification({ type: 'inform', title: t('placement'), message: t('placementHint') });
    post('adminStartPlacement', { target, initial }).then(pos => {
        document.getElementById('app').classList.remove('hidden');
        if (!pos || !pos.ok) return;
        const clean = { x: pos.x, y: pos.y, z: pos.z, w: pos.w || 0 };
        if (target === 'coords') coords = clean;
        if (target === 'store') store = clean;
        if (target === 'spawn') spawn = clean;
        updatePositionPreviews();
    });
}

function updatePositionPreviews() {
    document.getElementById('coordsPreview').innerText = fmtPos(coords);
    document.getElementById('storePreview').innerText = fmtPos(store);
    document.getElementById('spawnPreview').innerText = fmtPos(spawn);
}

function saveGarage() {
    const data = {
        id: document.getElementById('gId').value,
        label: document.getElementById('gLabel').value,
        type: document.getElementById('gType').value,
        job: document.getElementById('gJob').value,
        vehicleType: document.getElementById('gVehicleType').value,
        blip: document.getElementById('gBlip').checked,
        coords,
        store,
        spawn
    };
    post('adminCreateGarage', data).then(res => {
        if (res && res.ok) {
            const cleanId = String(data.id || '').trim();
            if (cleanId) {
                garages[cleanId] = { ...data, id: cleanId };
                renderAdminGarages();
                if (data.type === 'job') openJobGarage(cleanId, 'edit');
            }
        }
    });
}

function deleteGarage(id) {
    post('adminDeleteGarage', { id }).then(res => {
        if (res && res.ok) {
            delete garages[id];
            if (selectedJobGarageId === id) {
                selectedJobGarageId = null;
                setAdminPage('main');
            }
            renderAdminGarages();
        }
    });
}

function editGarage(id) {
    const g = garages[id];
    if (!g) return;
    document.getElementById('gId').value = g.id;
    document.getElementById('gLabel').value = g.label;
    document.getElementById('gType').value = g.type;
    document.getElementById('gJob').value = g.job || '';
    document.getElementById('gVehicleType').value = g.vehicleType || g.vehicle_type || 'car';
    document.getElementById('gBlip').checked = !!g.blip;
    coords = g.coords;
    store = g.store || g.coords;
    spawn = g.spawn;
    toggleJobField();
    updatePositionPreviews();

    if (g.type === 'job') {
        adminTab = 'job';
        setAdminTab('job');
        selectedJobGarageId = g.id;
        const jvGarage = document.getElementById('jvGarageId');
        if (jvGarage) jvGarage.value = g.id;
        renderJobVehicles();
    } else {
        selectedJobGarageId = null;
        setAdminPage('main');
    }
}

function showJobWorkspace(show, garage = null) {
    const panel = document.getElementById('jobGarageWorkspace');
    if (!panel) return;
    panel.classList.toggle('hidden', !show);
    if (show && garage) {
        document.getElementById('jobWorkspaceTitle').innerText = t('factionTitle', { garage: garage.label || garage.id });
        document.getElementById('jobVehicleSubtitle').innerText = `Job ${garage.job || 'nicht gesetzt'} · ${garageTypeLabel(garage.vehicleType || 'car')}`;
        document.getElementById('jvGarageId').value = garage.id;
    }
}

function openJobGarage(id, subTab = 'vehicles') {
    const g = garages[id];
    if (!g) return;
    if (subTab === 'edit') {
        editGarage(id);
        return;
    }
    selectedJobGarageId = id;
    const jvGarage = document.getElementById('jvGarageId');
    if (jvGarage) jvGarage.value = id;
    adminTab = 'job';
    document.getElementById('tabPublic')?.classList.remove('active');
    document.getElementById('tabJob')?.classList.add('active');
    setAdminPage('jobVehicles');
    showJobWorkspace(true, g);
    resetJobVehicleForm();
    renderJobVehicles();
}

function backToJobGarages() {
    adminTab = 'job';
    setAdminTab('job');
}

function editSelectedJobGarage() {
    if (!selectedJobGarageId) return;
    editGarage(selectedJobGarageId);
}

function renderAdminGarages() {
    const publicList = document.getElementById('adminPublicGarageList');
    const jobList = document.getElementById('adminJobGarageList');
    if (publicList) publicList.innerHTML = '';
    if (jobList) jobList.innerHTML = '';

    const all = Object.values(garages);
    const publicGarages = all.filter(g => g.type !== 'job');
    const jobGarages = all.filter(g => g.type === 'job');

    if (publicList && !publicGarages.length) publicList.innerHTML = `<div class="meta">${t('noPublicGarages')}</div>`;
    if (jobList && !jobGarages.length) jobList.innerHTML = `<div class="meta">${t('noJobGarages')}</div>`;

    publicGarages.forEach(g => publicList && publicList.appendChild(renderGarageRow(g, false)));
    jobGarages.forEach(g => jobList && jobList.appendChild(renderGarageRow(g, true)));
}

function renderGarageRow(g, isJob) {
    const row = document.createElement('div');
    row.className = 'garage-row' + (selectedJobGarageId === g.id ? ' selected' : '');
    row.innerHTML = `
        <div>
            <strong>${escapeHtml(g.label)}</strong>
            <span class="badge ${isJob ? 'job' : ''}">${isJob ? t('jobGarage') : t('public')}</span>
            ${g.job ? `<span class="badge">${escapeHtml(g.job)}</span>` : ''}
            <span class="badge type">${garageTypeLabel(g.vehicleType || 'car')}</span>
            <div class="meta">ID: ${escapeHtml(g.id)}</div>
        </div>
        <div class="row-actions">
            ${isJob ? `<button class="accent" onclick="openJobGarage('${escapeJs(g.id)}', 'vehicles')">${t('vehicles')}</button>` : `<button onclick="editGarage('${escapeJs(g.id)}')">${t('edit')}</button>`}
            ${isJob ? `<button onclick="openJobGarage('${escapeJs(g.id)}', 'edit')">${t('editGarage')}</button>` : ''}
            <button class="danger" onclick="deleteGarage('${escapeJs(g.id)}')">${t('delete')}</button>
        </div>
    `;
    return row;
}

function saveJobVehicle() {
    const id = document.getElementById('jvId').value;
    const data = {
        garageId: selectedJobGarageId || document.getElementById('jvGarageId').value || document.getElementById('gId').value,
        model: document.getElementById('jvModel').value,
        label: document.getElementById('jvLabel').value,
        primary: {
            r: Number(document.getElementById('jvPr').value),
            g: Number(document.getElementById('jvPg').value),
            b: Number(document.getElementById('jvPb').value)
        },
        secondary: {
            r: Number(document.getElementById('jvSr').value),
            g: Number(document.getElementById('jvSg').value),
            b: Number(document.getElementById('jvSb').value)
        }
    };
    delete data.id;
    if (id) data.id = Number(id);

    if (!data.garageId || !garages[data.garageId] || garages[data.garageId].type !== 'job') {
        showNotification({ type: 'error', title: t('jobGarageMissing'), message: t('openJobGarageFirst') });
        return;
    }

    const endpoint = id ? 'adminUpdateJobVehicle' : 'adminAddJobVehicle';
    post(endpoint, data).then(res => {
        if (res && res.ok) {
            jobVehicles = res.vehicles || [];
            renderJobVehicles();
            resetJobVehicleForm();
        }
    });
}

function addJobVehicle() { saveJobVehicle(); }

function editJobVehicle(id) {
    const v = jobVehicles.find(x => Number(x.id) === Number(id));
    if (!v) return;
    document.getElementById('jvId').value = v.id;
    document.getElementById('jvGarageId').value = v.garageId;
    document.getElementById('jvModel').value = v.model || '';
    document.getElementById('jvLabel').value = v.label || '';
    document.getElementById('jvPr').value = Number(v.primary?.r ?? 255);
    document.getElementById('jvPg').value = Number(v.primary?.g ?? 255);
    document.getElementById('jvPb').value = Number(v.primary?.b ?? 255);
    document.getElementById('jvSr').value = Number(v.secondary?.r ?? 255);
    document.getElementById('jvSg').value = Number(v.secondary?.g ?? 255);
    document.getElementById('jvSb').value = Number(v.secondary?.b ?? 255);
    document.getElementById('jobVehicleFormTitle').innerText = t('editVehicle');
    document.getElementById('jobVehicleSaveBtn').innerText = t('saveChanges');
}

function resetJobVehicleForm() {
    const ids = ['jvId', 'jvModel', 'jvLabel'];
    ids.forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
    ['jvPr','jvPg','jvPb','jvSr','jvSg','jvSb'].forEach(id => { const el = document.getElementById(id); if (el) el.value = 255; });
    if (selectedJobGarageId && document.getElementById('jvGarageId')) document.getElementById('jvGarageId').value = selectedJobGarageId;
    if (document.getElementById('jobVehicleFormTitle')) document.getElementById('jobVehicleFormTitle').innerText = t('createVehicle');
    if (document.getElementById('jobVehicleSaveBtn')) document.getElementById('jobVehicleSaveBtn').innerText = t('createVehicle');
}

function deleteJobVehicle(id) {
    post('adminDeleteJobVehicle', { id }).then(res => {
        if (res && res.ok) {
            jobVehicles = res.vehicles || [];
            renderJobVehicles();
            resetJobVehicleForm();
        }
    });
}

function renderJobVehicles() {
    const list = document.getElementById('adminJobVehicleList');
    if (!list) return;
    list.innerHTML = '';

    if (!selectedJobGarageId) {
        list.innerHTML = `<div class="meta">${t('selectJobGarageFirst')}</div>`;
        return;
    }

    const shown = jobVehicles.filter(v => String(v.garageId) === String(selectedJobGarageId));
    if (!shown.length) {
        list.innerHTML = `<div class="meta">${t('noJobVehicles')}</div>`;
        return;
    }
    shown.forEach(v => {
        const row = document.createElement('div');
        row.className = 'job-vehicle-row faction-vehicle-card';
        row.innerHTML = `
            <div class="faction-vehicle-top">
                <div>
                    <strong>${escapeHtml(v.label || v.model)}</strong>
                    <div class="meta">${t('spawnnamePrefix', { model: escapeHtml(v.model) })}</div>
                </div>
                <span class="badge job">Job</span>
            </div>
            <div class="vehicle-colors inline">
                <div class="color-pill"><i style="background:${rgbCss(v.primary)}"></i><span>${t('primary')} ${rgbText(v.primary)}</span></div>
                <div class="color-pill"><i style="background:${rgbCss(v.secondary)}"></i><span>${t('secondary')} ${rgbText(v.secondary)}</span></div>
            </div>
            <div class="row-actions faction-actions">
                <button onclick="editJobVehicle(${Number(v.id)})">${t('edit')}</button>
                <button class="danger" onclick="deleteJobVehicle(${Number(v.id)})">${t('delete')}</button>
            </div>
        `;
        list.appendChild(row);
    });
}

function escapeHtml(str) {
    return String(str).replace(/[&<>'"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[c]));
}
function escapeJs(str) { return String(str).replace(/\\/g, '\\\\').replace(/'/g, "\\'"); }

window.addEventListener('message', e => {
    const data = e.data;
    if (data.action === 'notify') {
        showNotification(data);
    }
    if (data.action === 'setVehicleImage') {
        setVehicleImage(data.modelKey, data.image);
    }
    if (data.action === 'hideForPlacement') {
        document.getElementById('app').classList.add('hidden');
    }
    if (data.action === 'showAfterPlacement') {
        document.getElementById('app').classList.remove('hidden');
    }
    if (data.action === 'openGarage') {
        if (window.setLocale) setLocale(data.locale || 'de');
        resource = data.resource || resource;
        window.currentGarageData = data.garage || {};
        currentGarageIsJob = (data.garage && data.garage.type === 'job');
        document.getElementById('title').innerText = data.garage?.label || t('garage');
        document.getElementById('subtitle').innerText = `${data.garage?.type === 'job' ? t('jobGarageLabel', { job: data.garage.job }) : t('publicGarageImpound')} · ${garageTypeLabel(data.garage?.vehicleType || 'car')}`;
        garageTab = 'vehicles';
        document.getElementById('garageTabVehicles')?.classList.add('active');
        document.getElementById('garageTabImpound')?.classList.remove('active');
        document.getElementById('garageTabVehicles')?.classList.remove('hidden');
        document.getElementById('garageModeTabs')?.classList.remove('hidden');
        const impoundTab = document.getElementById('garageTabImpound');
        if (impoundTab) {
            impoundTab.classList.toggle('hidden', currentGarageIsJob);
            impoundTab.style.display = currentGarageIsJob ? 'none' : 'inline-flex';
        }
        document.getElementById('garageTypeKicker').innerText = `// ${t('garage').toUpperCase()}`;
        vehicles = data.vehicles || [];
        show('garage');
        if (window.applyTranslations) applyTranslations();
        renderVehicles();
    }
    if (data.action === 'openAdmin') {
        if (window.setLocale) setLocale(data.locale || 'de');
        resource = data.resource || resource;
        garages = data.garages || {};
        jobVehicles = data.jobVehicles || [];
        selectedJobGarageId = null;
        coords = data.position || null;
        store = data.position || null;
        spawn = data.position || null;
        document.getElementById('title').innerText = t('adminTitle');
        document.getElementById('subtitle').innerText = t('adminSubtitle');
        show('admin');
        if (window.applyTranslations) applyTranslations();
        setAdminTab('public');
        setAdminPage('main');
        newGarageForm();
        renderAdminGarages();
        renderJobVehicles();
        updatePositionPreviews();
    }
    if (data.action === 'close') {
        document.getElementById('app').classList.add('hidden');
    }
});

document.addEventListener('click', e => {
    const closeButton = e.target.closest('[data-close-ui]');
    if (closeButton) closeUi(e);
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeUi(e);
});
