const state = {
  token: sessionStorage.getItem('lanEditToken') || '',
  pin: sessionStorage.getItem('lanEditPin') || '',
  meta: null,
  courses: [],
  session: null,
  editingGroupName: null,
  viewWeek: 1,
  loading: false,
  courseSearch: '',
  filterNature: '',
  sessionTimerId: null,
  activeTab: 'overview',
  logs: JSON.parse(sessionStorage.getItem('lanEditLogs') || '[]'),
  selectedBackupFileContent: null,
};

// UI 元素声明
const loginView = document.getElementById('login-view');
const editorView = document.getElementById('editor-view');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const profileName = document.getElementById('profile-name');
const weekLabel = document.getElementById('week-label');
const grid = document.getElementById('timetable-grid');
const modal = document.getElementById('editor-modal');
const courseForm = document.getElementById('course-form');
const formError = document.getElementById('form-error');
const deleteCourseBtn = document.getElementById('delete-course-btn');
const duplicateCourseBtn = document.getElementById('duplicate-course-btn');
const colorInput = document.getElementById('color-input');
const colorSwatches = document.getElementById('color-swatches');
const loadingOverlay = document.getElementById('loading-overlay');
const loadingText = document.getElementById('loading-text');
const weekPicker = document.getElementById('week-picker');
const courseSearch = document.getElementById('course-search');
const filterNature = document.getElementById('filter-nature');
const courseCount = document.getElementById('course-count');
const sessionBadge = document.getElementById('session-badge');
const sessionCountdown = document.getElementById('session-countdown');
const toastContainer = document.getElementById('toast-container');

// Tab 面板
const navItems = document.querySelectorAll('.nav-item');
const tabPanels = document.querySelectorAll('.tab-panel');
const pageTitle = document.getElementById('page-title');

// 概览页指标元素
const todayCourseList = document.getElementById('today-course-list');
const overviewTodayDate = document.getElementById('overview-today-date');
const infoIp = document.getElementById('info-ip');
const infoPort = document.getElementById('info-port');
const infoPin = document.getElementById('info-pin');
const infoClients = document.getElementById('info-clients');

// 备份与作息
const btnExportBackup = document.getElementById('btn-export-backup');
const btnImportBackup = document.getElementById('btn-import-backup');
const backupProfileName = document.getElementById('backup-profile-name');
const dropZone = document.getElementById('drop-zone');
const backupFileInput = document.getElementById('backup-file-input');
const selectedFilename = document.getElementById('selected-filename');
const metaSectionsContainer = document.getElementById('meta-sections-container');
const btnAddSlotField = document.getElementById('btn-add-slot-field');
const scheduleSlotsContainer = document.getElementById('schedule-slots-container');
const spreadsheetDropZone = document.getElementById('spreadsheet-drop-zone');
const spreadsheetFileInput = document.getElementById('spreadsheet-file-input');
const spreadsheetSelectedFilename = document.getElementById('spreadsheet-selected-filename');
const btnImportSpreadsheet = document.getElementById('btn-import-spreadsheet');
const spreadsheetReplaceExisting = document.getElementById('spreadsheet-replace-existing');
const spreadsheetImportResult = document.getElementById('spreadsheet-import-result');
const syncPhoneWeekBtn = document.getElementById('sync-phone-week-btn');
const mergeDropZone = document.getElementById('merge-drop-zone');
const mergeFileInput = document.getElementById('merge-file-input');
const mergeSelectedFilename = document.getElementById('merge-selected-filename');
const btnImportMerge = document.getElementById('btn-import-merge');
const mergeImportResult = document.getElementById('merge-import-result');
const btnBatchDeleteCourses = document.getElementById('btn-batch-delete-courses');

let slotCounter = 0;
let selectedSpreadsheetFile = null;
let selectedMergeFileContent = null;
const selectedCourseIds = new Set();

function updateLibraryBatchDeleteUi() {
  if (!btnBatchDeleteCourses) return;
  const count = selectedCourseIds.size;
  if (count === 0) {
    hide(btnBatchDeleteCourses);
    btnBatchDeleteCourses.disabled = true;
    return;
  }
  show(btnBatchDeleteCourses);
  btnBatchDeleteCourses.disabled = false;
  btnBatchDeleteCourses.textContent = `批量删除选中 (${count})`;
}

function formatWeeksForExpression(weeks) {
  if (!weeks || !weeks.length) return '';
  return weeks.join('、');
}

function readFileAsBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result;
      const base64 = String(dataUrl).split(',')[1] || '';
      resolve(base64);
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

// 通用助手函数
function show(el) {
  if (el) el.classList.remove('hidden');
}

function hide(el) {
  if (el) el.classList.add('hidden');
}

/** Tabler/Bootstrap 5 标准模态框（tabler.min.js 提供 bootstrap.Modal） */
let _courseBootstrapModal = null;
function getCourseBootstrapModal() {
  if (!modal) return null;
  const BsModal = window.bootstrap?.Modal;
  if (!BsModal) return null;
  if (!_courseBootstrapModal) {
    _courseBootstrapModal = new BsModal(modal, { backdrop: true, keyboard: true });
  }
  return _courseBootstrapModal;
}

function showCourseModal() {
  const bs = getCourseBootstrapModal();
  if (bs) {
    bs.show();
    return;
  }
  modal.classList.remove('hidden');
  modal.classList.add('show');
  modal.style.display = 'block';
  modal.setAttribute('aria-modal', 'true');
  document.body.classList.add('modal-open');
  if (!document.getElementById('lan-modal-backdrop')) {
    const backdrop = document.createElement('div');
    backdrop.className = 'modal-backdrop fade show';
    backdrop.id = 'lan-modal-backdrop';
    document.body.appendChild(backdrop);
  }
}

function hideCourseModal() {
  const bs = getCourseBootstrapModal();
  if (bs) {
    bs.hide();
    return;
  }
  modal.classList.remove('show');
  modal.style.display = '';
  modal.classList.add('hidden');
  modal.removeAttribute('aria-modal');
  document.body.classList.remove('modal-open');
  document.getElementById('lan-modal-backdrop')?.remove();
}

function setError(el, message) {
  if (!message) {
    hide(el);
    el.textContent = '';
    return;
  }
  el.textContent = message;
  show(el);
}

function setLoading(isLoading, text = '加载课表数据…') {
  state.loading = isLoading;
  if (isLoading) {
    loadingText.textContent = text;
    show(loadingOverlay);
  } else {
    hide(loadingOverlay);
  }
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  toastContainer.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('visible'));
  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => toast.remove(), 300);
  }, 3200);
}

// 审计日志助手
function addActivityLog(action, detail) {
  const log = {
    time: new Date().toLocaleTimeString(),
    action,
    detail
  };
  state.logs.unshift(log);
  if (state.logs.length > 50) state.logs.pop();
  sessionStorage.setItem('lanEditLogs', JSON.stringify(state.logs));
  renderActivityLog();
}

function renderActivityLog() {
  const listEl = document.getElementById('activity-log-list');
  if (!listEl) return;
  if (state.logs.length === 0) {
    listEl.innerHTML = '<div class="log-empty-hint">暂无操作记录</div>';
    return;
  }
  listEl.innerHTML = state.logs.map(log => `
    <div class="log-item">
      <span class="log-time">${log.time}</span>
      <span class="log-action badge badge-success">${log.action}</span>
      <span class="log-detail">${log.detail}</span>
    </div>
  `).join('');
}

// HTTP API 封装
async function api(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }
  if (options.body && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json';
  }
  const response = await fetch(path, { ...options, headers });
  const text = await response.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { message: text };
    }
  }
  if (!response.ok) {
    const code = response.status;
    if (code === 502 || code === 504) {
      throw new Error(
        '无法连上手机上的编辑服务（HTTP ' +
          code +
          '）。请确认：① 手机 App 里「局域网编辑」仍为开启状态；② 电脑与手机在同一 WiFi 或手机热点；③ 浏览器地址为手机显示的 IP:端口（勿用 localhost）；④ 勿经 IDE/插件端口转发打开页面。'
      );
    }
    if (code === 503) {
      throw new Error('手机端编辑服务正在关闭或尚未就绪，请在 App 中重新开启局域网编辑。');
    }
    if (code === 401) {
      const reason = data.error || data.message || '';
      if (reason === 'session_expired' || String(data.message || '').includes('expired')) {
        throw new Error('会话已过期，请在手机端重新开启局域网编辑并重新登录。');
      }
      throw new Error(data.message || data.error || '未授权，请重新输入 PIN');
    }
    throw new Error(data.message || data.error || `HTTP ${code}`);
  }
  return data;
}

// 核心周数计算逻辑
function courseInWeek(course, week) {
  if (course.suspendedWeeks && course.suspendedWeeks.includes(week)) {
    return false;
  }
  if (course.customWeeks && course.customWeeks.length) {
    return course.customWeeks.includes(week);
  }
  if (week < course.startWeek || week > course.endWeek) {
    return false;
  }
  if (course.isOddWeek && week % 2 === 0) return false;
  if (course.isEvenWeek && week % 2 === 1) return false;
  return true;
}

// 分组计算逻辑 (核心：将一门课的多个上课时间聚合成一个 CourseGroup)
function getCourseGroups(coursesList) {
  const groupsMap = {};
  coursesList.forEach(course => {
    const key = course.name.trim();
    if (!groupsMap[key]) {
      groupsMap[key] = {
        name: course.name,
        shortName: course.shortName || '',
        color: course.color || '#2196F3',
        courseNature: course.courseNature || 'required',
        note: course.note || course.description || '',
        courses: [],
      };
    }
    groupsMap[key].courses.push(course);
  });
  return Object.values(groupsMap);
}

function coursesForViewWeek() {
  return state.courses.filter((course) => courseInWeek(course, state.viewWeek));
}

function coursesStartingAt(dayOfWeek, section) {
  return coursesForViewWeek().filter(
    (course) => course.dayOfWeek === dayOfWeek && course.startSection === section,
  );
}

function todayDayOfWeek() {
  const day = new Date().getDay();
  return day === 0 ? 7 : day;
}

function getWeekdayCn(index) {
  return ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][index] || '';
}

function weekdayHeaderText(label, index) {
  const fallback = ['一', '二', '三', '四', '五', '六', '日'][index] || String(index + 1);
  const raw = label || fallback;
  if (String(raw).startsWith('周')) {
    return raw;
  }
  return `周${raw}`;
}

function contrastTextColor(hex) {
  const value = (hex || '#2563eb').replace('#', '');
  if (value.length !== 6) return '#ffffff';
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.62 ? '#1f2937' : '#ffffff';
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function courseDisplayName(course) {
  return course.shortName?.trim() || course.name;
}

// 仪表盘渲染函数
function renderDashboard() {
  if (!state.meta) return;

  const phoneWeek = state.meta.currentWeek;
  const today = todayDayOfWeek();
  const todayName = getWeekdayCn(today - 1);
  
  overviewTodayDate.textContent = `第 ${phoneWeek} 周 · ${todayName}`;

  // 今日课程 (从当前查看的周中读取今日的课程)
  const todayCourses = state.courses
    .filter(course => course.dayOfWeek === today && courseInWeek(course, phoneWeek))
    .sort((a, b) => a.startSection - b.startSection);

  todayCourseList.innerHTML = '';
  if (todayCourses.length === 0) {
    todayCourseList.innerHTML = '<li class="empty-list-hint">🎉 今天放假啦，没有检测到今天的课程计划</li>';
  } else {
    todayCourses.forEach(course => {
      const item = document.createElement('li');
      item.className = 'list-card-item';

      const sectionText = course.startSection === course.endSection 
        ? `第 ${course.startSection} 节` 
        : `第 ${course.startSection}-${course.endSection} 节`;

      const typeBadge = course.courseNature === 'elective'
        ? '<span class="badge badge-success">选修</span>'
        : '<span class="badge badge-danger">必修</span>';

      item.innerHTML = `
        <div class="item-color-indicator" style="background-color: ${course.color || '#4f46e5'}"></div>
        <div class="item-info">
          <h4>${escapeHtml(course.name)}</h4>
          <p>${escapeHtml(course.teacher || '未填教师')} · 📍 ${escapeHtml(course.location || '未指定教室')}</p>
        </div>
        <div class="item-meta">
          <div><strong>${sectionText}</strong></div>
          <div style="margin-top: 4px;">${typeBadge}</div>
        </div>
      `;
      item.addEventListener('click', () => {
        state.activeTab = 'timetable';
        syncTabsUI();
        const groups = getCourseGroups(state.courses);
        const group = groups.find(g => g.name === course.name);
        if (group) openEditor(group);
      });
      todayCourseList.appendChild(item);
    });
  }

  // 本地服务明细
  infoIp.textContent = window.location.hostname;
  infoPort.textContent = window.location.port || '80';
  infoPin.textContent = state.pin || '通过 App 界面查看';
  
  const connectedDevices = state.session?.connectedClientCount || 1;
  infoClients.textContent = `${connectedDevices} 台设备`;

  // 备份的课表档案名字
  backupProfileName.textContent = state.session?.profileName || state.meta.profileName || '当前课表';

  renderActivityLog();
}

// 课表网格视图渲染 (Timetable Grid)
function buildCourseBlock(course) {
  const block = document.createElement('div');
  block.className = 'course-block';
  const bg = course.color || '#2563eb';
  block.style.background = bg;
  block.style.color = contrastTextColor(bg);
  block.dataset.courseId = course.id;

  const nature =
    course.courseNature === 'elective'
      ? '<span class="course-nature elective">选修</span>'
      : '<span class="course-nature">必修</span>';

  const teacher = course.teacher?.trim()
    ? `<span class="course-teacher">${escapeHtml(course.teacher)}</span>`
    : '';
  const location = course.location?.trim()
    ? `<span class="course-location">${escapeHtml(course.location)}</span>`
    : '';

  block.innerHTML = `
    <div class="course-block-header">
      <strong>${escapeHtml(courseDisplayName(course))}</strong>
      ${nature}
    </div>
    ${teacher}
    ${location}
  `;

  block.addEventListener('click', (event) => {
    event.stopPropagation();
    const groups = getCourseGroups(state.courses);
    const group = groups.find(g => g.name === course.name);
    if (group) openEditor(group);
  });
  return block;
}

function renderGrid() {
  if (!state.meta) return;
  grid.innerHTML = '';
  const sections = state.meta.sections || [];
  const weekdays = state.meta.weekdayLabels || [];
  const occupied = new Set();
  const today = todayDayOfWeek();

  const header = document.createElement('tr');
  header.appendChild(document.createElement('th'));
  for (let day = 1; day <= 7; day += 1) {
    const th = document.createElement('th');
    const label = weekdayHeaderText(weekdays[day - 1], day - 1);
    th.dataset.day = String(day);
    if (day === today) {
      th.classList.add('today-col');
      th.title = '今日';
      th.innerHTML = `<span class="day-label">${escapeHtml(label)}</span><span class="today-badge">今日</span>`;
    } else {
      th.textContent = label;
    }
    header.appendChild(th);
  }
  grid.appendChild(header);

  sections.forEach((section, index) => {
    const sectionNum = index + 1;
    const row = document.createElement('tr');

    const timeCell = document.createElement('td');
    timeCell.className = 'time-col';
    timeCell.innerHTML = `<span class="section-num">${sectionNum}</span><span class="section-time">${escapeHtml(section.startTime)}-${escapeHtml(section.endTime)}</span>`;
    row.appendChild(timeCell);

    for (let day = 1; day <= 7; day += 1) {
      const key = `${day}-${sectionNum}`;
      if (occupied.has(key)) {
        continue;
      }

      const cell = document.createElement('td');
      cell.className = 'slot-cell';
      cell.dataset.day = String(day);
      cell.dataset.section = String(sectionNum);
      if (day === today) {
        cell.classList.add('today-col');
      }

      const startingCourses = coursesStartingAt(day, sectionNum);
      startingCourses.forEach((course) => {
        const span = Math.max(1, course.endSection - course.startSection + 1);
        const block = buildCourseBlock(course);
        if (span > 1 && startingCourses.length === 1) {
          cell.rowSpan = span;
          for (let s = sectionNum + 1; s <= course.endSection; s += 1) {
            occupied.add(`${day}-${s}`);
          }
          block.classList.add('course-block-span');
        }
        cell.appendChild(block);
      });

      cell.addEventListener('click', () => openEditor(null, day, sectionNum));
      row.appendChild(cell);
    }

    grid.appendChild(row);
  });
}

// 课程库管理：用卡片网格渲染分组后的课程
function renderCoursesTable() {
  const container = document.getElementById('courses-cards-container');
  if (!container) return;

  const searchQuery = state.courseSearch.trim().toLowerCase();
  const groups = getCourseGroups(state.courses);

  // 过滤课程组
  const filteredGroups = groups.filter(group => {
    // 模糊搜索：匹配课程名、简称、教师、教室、备注
    if (searchQuery) {
      const matchText = [
        group.name,
        group.shortName,
        group.note,
        group.courses.map(c => c.teacher).join(' '),
        group.courses.map(c => c.location).join(' '),
      ].filter(Boolean).join(' ').toLowerCase();
      if (!matchText.includes(searchQuery)) return false;
    }

    // 性质过滤
    if (state.filterNature && group.courseNature !== state.filterNature) {
      return false;
    }

    return true;
  }).sort((a, b) => a.name.localeCompare(b.name, 'zh-CN'));

  courseCount.textContent = String(filteredGroups.length);
  container.innerHTML = '';
  selectedCourseIds.clear();
  updateLibraryBatchDeleteUi();

  if (filteredGroups.length === 0) {
    container.innerHTML = `
      <div class="empty-list-hint col-span-2" style="width: 100%; grid-column: 1 / -1;">
        没有匹配的课程，请修改搜索过滤条件或点击右上方新建课程。
      </div>
    `;
    return;
  }

  filteredGroups.forEach(group => {
    const card = document.createElement('div');
    card.className = 'course-group-card';
    
    // 生成上课时间段的 HTML 列表
    const slotsHtml = group.courses.map(course => {
      const dayName = getWeekdayCn(course.dayOfWeek - 1);
      const sectionText = course.startSection === course.endSection
        ? `第 ${course.startSection} 节`
        : `第 ${course.startSection}-${course.endSection} 节`;

      let weekText = `第 ${course.startWeek}-${course.endWeek} 周`;
      if (course.isOddWeek) weekText += ' (单周)';
      else if (course.isEvenWeek) weekText += ' (双周)';

      return `
        <div class="card-slot-item">
          <span class="slot-time">📅 ${dayName} ${sectionText} <span class="slot-weeks">(${weekText})</span></span>
          <div class="slot-details">
            ${course.teacher ? `<span class="slot-detail-pill">👤 ${escapeHtml(course.teacher)}</span>` : ''}
            ${course.location ? `<span class="slot-detail-pill">📍 ${escapeHtml(course.location)}</span>` : ''}
          </div>
        </div>
      `;
    }).join('');

    const natureBadge = group.courseNature === 'elective'
      ? '<span class="badge bg-green-lt">选修</span>'
      : '<span class="badge bg-red-lt">必修</span>';

    card.className = 'card course-group-card';
    card.innerHTML = `
      <div class="card-header-band" style="background-color: ${group.color || '#4f46e5'}"></div>
      <div class="card-body">
        <div class="d-flex align-items-start gap-2 mb-2">
          <label class="form-check mb-0" title="批量删除">
            <input type="checkbox" class="form-check-input library-course-select" data-course-ids="${group.courses.map(c => c.id).join(',')}" />
          </label>
          <div class="flex-fill">
            <h3 class="card-title mb-0">${escapeHtml(group.name)}</h3>
            ${group.shortName ? `<div class="text-secondary small">${escapeHtml(group.shortName)}</div>` : ''}
          </div>
          ${natureBadge}
        </div>
        <div class="card-slots-list">${slotsHtml}</div>
        ${group.note ? `<p class="text-secondary small mt-2 mb-0">📝 ${escapeHtml(group.note)}</p>` : ''}
        <div class="btn-list mt-3">
          <button type="button" class="btn btn-sm action-edit-btn">编辑</button>
          <button type="button" class="btn btn-sm action-copy-btn">复制</button>
          <button type="button" class="btn btn-sm btn-danger action-delete-btn">删除</button>
        </div>
      </div>
    `;

    // 绑定事件
    card.querySelector('.action-edit-btn').addEventListener('click', () => openEditor(group));
    card.querySelector('.action-copy-btn').addEventListener('click', () => {
      openEditor(group);
      state.editingGroupName = null; // 变成新建模式
      document.getElementById('modal-title').textContent = '复制并新建课程';
      courseForm.name.value = `${group.name} (副本)`;
      // 重置 slots 里的 id 以便生成全新课程记录
      const slotInputs = scheduleSlotsContainer.querySelectorAll('.slot-card');
      slotInputs.forEach(slotCard => {
        slotCard.dataset.id = '';
      });
      hide(deleteCourseBtn);
      hide(duplicateCourseBtn);
    });
    card.querySelector('.action-delete-btn').addEventListener('click', () => deleteCourseGroupDirectly(group));

    const selectInput = card.querySelector('.library-course-select');
    selectInput.addEventListener('change', () => {
      const ids = (selectInput.dataset.courseIds || '').split(',').filter(Boolean);
      if (selectInput.checked) {
        ids.forEach((id) => selectedCourseIds.add(id));
      } else {
        ids.forEach((id) => selectedCourseIds.delete(id));
      }
      updateLibraryBatchDeleteUi();
    });

    container.appendChild(card);
  });
}

// 快速删除整个课程
async function deleteCourseGroupDirectly(group) {
  if (!window.confirm(`确定要彻底删除课程《${group.name}》的全部 ${group.courses.length} 个上课时间段吗？`)) return;
  try {
    setLoading(true, '正在删除课程数据…');
    for (const course of group.courses) {
      await api(`/api/v1/courses/${encodeURIComponent(course.id)}`, {
        method: 'DELETE',
      });
    }
    showToast('整个课程已删除', 'success');
    addActivityLog('删除课程', `删除了整个课程 [${group.name}]`);
    await loadEditorData({ silent: true });
  } catch (error) {
    showToast('删除失败: ' + error.message, 'error');
  } finally {
    setLoading(false);
  }
}

// 备份与作息配置渲染
function renderBackupView() {
  if (!state.meta) return;

  // 渲染作息时间表
  const sections = state.meta.sections || [];
  metaSectionsContainer.innerHTML = '';
  if (sections.length === 0) {
    metaSectionsContainer.innerHTML = '<p class="text-muted">无作息时间配置</p>';
  } else {
    sections.forEach((section, index) => {
      const card = document.createElement('div');
      card.className = 'meta-section-card';
      card.innerHTML = `
        <div class="meta-section-badge">${index + 1}</div>
        <div class="meta-section-info">
          <span class="meta-section-name">第 ${index + 1} 节课</span>
          <span class="meta-section-time">⏰ ${escapeHtml(section.startTime)} - ${escapeHtml(section.endTime)}</span>
        </div>
      `;
      metaSectionsContainer.appendChild(card);
    });
  }
}

// 备份导入导出操作
btnExportBackup.addEventListener('click', async () => {
  try {
    setLoading(true, '正在生成备份文件…');
    const data = await api('/api/v1/profile/active');
    const jsonStr = JSON.stringify(data, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    
    const profile = state.session?.profileName || state.meta?.profileName || 'backup';
    const dateStr = new Date().toISOString().slice(0, 10);
    
    a.href = url;
    a.download = `轻屿课表备份_${profile}_${dateStr}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showToast('备份文件已下载', 'success');
    addActivityLog('备份导出', `成功导出了课表档案 [${profile}]`);
  } catch (error) {
    showToast('备份导出失败: ' + error.message, 'error');
  } finally {
    setLoading(false);
  }
});

btnImportBackup.addEventListener('click', async () => {
  const content = state.selectedBackupFileContent;
  if (!content) return;
  
  if (!window.confirm('⚠️ 警告：导入备份将覆盖手机里的现有全部数据。确定继续吗？')) {
    return;
  }

  try {
    setLoading(true, '正在覆盖手机端数据…');
    await api('/api/v1/profile/active', {
      method: 'PUT',
      body: content,
    });
    showToast('备份导入成功！手机端数据已同步', 'success');
    addActivityLog('备份导入', '覆盖性导入了备份文件');
    
    state.selectedBackupFileContent = null;
    selectedFilename.textContent = '未选择文件';
    hide(selectedFilename);
    btnImportBackup.disabled = true;
    
    await loadEditorData();
    setViewTab('overview');
  } catch (error) {
    showToast('备份导入失败: ' + error.message, 'error');
  } finally {
    setLoading(false);
  }
});

// 拖拽上传逻辑
dropZone.addEventListener('click', () => backupFileInput.click());

backupFileInput.addEventListener('change', (e) => {
  handleSelectedFile(e.target.files[0]);
});

dropZone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropZone.classList.add('dragover');
});

['dragleave', 'dragend'].forEach(type => {
  dropZone.addEventListener(type, () => dropZone.classList.remove('dragover'));
});

dropZone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropZone.classList.remove('dragover');
  if (e.dataTransfer.files.length) {
    handleSelectedFile(e.dataTransfer.files[0]);
  }
});

function handleSelectedFile(file) {
  if (!file) return;
  if (file.type !== 'application/json' && !file.name.endsWith('.json')) {
    showToast('只允许上传 .json 格式的备份文件', 'error');
    return;
  }
  
  const reader = new FileReader();
  reader.onload = (event) => {
    try {
      JSON.parse(event.target.result);
      state.selectedBackupFileContent = event.target.result;
      
      selectedFilename.textContent = `已选文件: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
      show(selectedFilename);
      btnImportBackup.disabled = false;
      showToast('文件解析成功，可以点击执行导入', 'info');
    } catch (e) {
      showToast('文件解析失败，请检查是否为合法 JSON 备份文件', 'error');
    }
  };
  reader.readAsText(file);
}

// 动态时间段表单项生成
function addSlotField(data = {}) {
  const slotId = `slot-${slotCounter++}`;
  const card = document.createElement('div');
  card.className = 'slot-card';
  card.id = slotId;
  card.dataset.id = data.id || ''; // 保存的原课程 ID (如果有)

  card.innerHTML = `
    <div class="slot-card-header">
      <h4>时间段</h4>
      <button type="button" class="btn-remove-slot" title="删除此时间段">&times; 删除</button>
    </div>
    <div class="form-grid">
      <div class="form-group">
        <label class="form-label">上课星期</label>
        <select class="field-slot-day select-modern">
          <option value="1" ${data.dayOfWeek == 1 ? 'selected' : ''}>周一</option>
          <option value="2" ${data.dayOfWeek == 2 ? 'selected' : ''}>周二</option>
          <option value="3" ${data.dayOfWeek == 3 ? 'selected' : ''}>周三</option>
          <option value="4" ${data.dayOfWeek == 4 ? 'selected' : ''}>周四</option>
          <option value="5" ${data.dayOfWeek == 5 ? 'selected' : ''}>周五</option>
          <option value="6" ${data.dayOfWeek == 6 ? 'selected' : ''}>周六</option>
          <option value="7" ${data.dayOfWeek == 7 ? 'selected' : ''}>周日</option>
        </select>
      </div>

      <div class="form-group form-inline-row">
        <div class="nested-group">
          <label class="form-label">开始节次</label>
          <input type="number" min="1" class="field-slot-startSection" value="${data.startSection || 1}" required />
        </div>
        <div class="nested-group">
          <label class="form-label">结束节次</label>
          <input type="number" min="1" class="field-slot-endSection" value="${data.endSection || 2}" required />
        </div>
      </div>

      <div class="form-group form-inline-row">
        <div class="nested-group">
          <label class="form-label">开始周</label>
          <input type="number" min="1" class="field-slot-startWeek" value="${data.startWeek || 1}" required />
        </div>
        <div class="nested-group">
          <label class="form-label">结束周</label>
          <input type="number" min="1" class="field-slot-endWeek" value="${data.endWeek || (state.meta?.semesterWeekCount || 20)}" required />
        </div>
      </div>

      <div class="form-group checkbox-group-row">
        <label class="checkbox-container">
          <input type="checkbox" class="field-slot-isOddWeek" ${data.isOddWeek ? 'checked' : ''} />
          <span class="checkbox-checkmark"></span>
          <span>仅单周</span>
        </label>
        <label class="checkbox-container">
          <input type="checkbox" class="field-slot-isEvenWeek" ${data.isEvenWeek ? 'checked' : ''} />
          <span class="checkbox-checkmark"></span>
          <span>仅双周</span>
        </label>
      </div>

      <div class="form-group">
        <label class="form-label">授课教师</label>
        <input type="text" class="field-slot-teacher" placeholder="可选，例如：张老师" value="${data.teacher || ''}" />
      </div>

      <div class="form-group">
        <label class="form-label">上课地点</label>
        <input type="text" class="field-slot-location" placeholder="可选，例如：主楼 201" value="${data.location || ''}" />
      </div>

      <div class="form-group col-span-2 slot-advanced">
        <label class="form-label">上课周（表达式，可选）</label>
        <div class="form-inline-row">
          <input type="text" class="field-slot-weekExpression" placeholder="如 1-8、10-16(单)；留空则用起止周+单双周" value="${escapeHtml(formatWeeksForExpression(data.customWeeks) || '')}" />
          <button type="button" class="btn btn-secondary btn-small btn-preview-week">预览</button>
        </div>
        <p class="field-hint field-slot-week-preview text-muted"></p>
      </div>
      <div class="form-group col-span-2 slot-advanced">
        <label class="form-label">停课周（表达式，可选）</label>
        <input type="text" class="field-slot-suspendedWeekExpression" placeholder="如 6、12" value="${escapeHtml(formatWeeksForExpression(data.suspendedWeeks) || '')}" />
      </div>
    </div>
  `;

  card.querySelector('.btn-preview-week')?.addEventListener('click', async () => {
    const input = card.querySelector('.field-slot-weekExpression');
    const preview = card.querySelector('.field-slot-week-preview');
    const expression = input.value.trim();
    if (!expression) {
      preview.textContent = '';
      return;
    }
    try {
      const result = await api('/api/v1/week-expression/parse', {
        method: 'POST',
        body: JSON.stringify({
          expression,
          itemName: courseForm?.name?.value?.trim() || '课程',
        }),
      });
      const weeks = result.weeks || [];
      preview.textContent = weeks.length
        ? `解析为周次：${weeks.join('、')}`
        : '未解析到有效周次';
    } catch (error) {
      preview.textContent = error.message;
    }
  });

  card.querySelector('.btn-remove-slot').addEventListener('click', () => {
    if (scheduleSlotsContainer.querySelectorAll('.slot-card').length <= 1) {
      showToast('课程必须包含至少一个上课时间段', 'error');
      return;
    }
    card.remove();
  });

  scheduleSlotsContainer.appendChild(card);
}

// 周次选择器填充
function fillWeekPicker() {
  const total = state.meta.semesterWeekCount || 20;
  weekPicker.innerHTML = '';
  for (let week = 1; week <= total; week += 1) {
    const option = document.createElement('option');
    option.value = String(week);
    option.textContent = `第 ${week} 周`;
    if (week === state.viewWeek) {
      option.selected = true;
    }
    weekPicker.appendChild(option);
  }
}

function updateWeekLabel() {
  const phoneWeek = state.meta.currentWeek;
  const total = state.meta.semesterWeekCount;
  const viewing = state.viewWeek;
  if (viewing === phoneWeek) {
    weekLabel.textContent = `第 ${viewing} 周（与手机同步中）/ 共 ${total} 周`;
  } else {
    weekLabel.textContent = `查看第 ${viewing} 周 · 手机当前第 ${phoneWeek} 周 / 共 ${total} 周`;
  }
}

function setViewWeek(week) {
  const total = state.meta?.semesterWeekCount || 20;
  state.viewWeek = Math.min(Math.max(1, week), total);
  weekPicker.value = String(state.viewWeek);
  updateWeekLabel();
  renderGrid();
  renderCoursesTable();
  renderDashboard();
}

// 颜色选择器
function fillColorSwatches(selectedColor) {
  const colors = state.meta.presetColors || ['#2196F3'];
  const color = selectedColor || colors[0];
  colorSwatches.innerHTML = '';
  colorInput.value = color;

  colors.forEach((preset) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'color-swatch';
    btn.style.background = preset;
    btn.title = preset;
    btn.dataset.color = preset;
    if (preset.toLowerCase() === String(color).toLowerCase()) {
      btn.classList.add('selected');
    }
    btn.addEventListener('click', () => {
      colorInput.value = preset;
      colorSwatches.querySelectorAll('.color-swatch').forEach((el) => {
        el.classList.toggle('selected', el.dataset.color === preset);
      });
    });
    colorSwatches.appendChild(btn);
  });
}

// 课程表单编辑 Modal (按组聚合打开)
function openEditor(courseGroup, defaultDay, defaultSection) {
  scheduleSlotsContainer.innerHTML = '';
  
  if (courseGroup) {
    state.editingGroupName = courseGroup.name;
    document.getElementById('modal-title').textContent = '编辑课程';
    courseForm.name.value = courseGroup.name || '';
    courseForm.shortName.value = courseGroup.shortName || '';
    courseForm.courseNature.value = courseGroup.courseNature || 'required';
    courseForm.note.value = courseGroup.note || '';
    fillColorSwatches(courseGroup.color);

    // 载入所有的上课时间段
    courseGroup.courses.forEach(c => {
      addSlotField(c);
    });

    show(deleteCourseBtn);
    show(duplicateCourseBtn);
  } else {
    state.editingGroupName = null;
    document.getElementById('modal-title').textContent = '新建课程';
    courseForm.name.value = '';
    courseForm.shortName.value = '';
    courseForm.courseNature.value = 'required';
    courseForm.note.value = '';
    fillColorSwatches(state.meta?.presetColors?.[0] || '#2196F3');

    // 默认提供一个上课时间段项
    addSlotField({
      dayOfWeek: defaultDay || 1,
      startSection: defaultSection || 1,
      endSection: defaultSection || 2,
    });

    hide(deleteCourseBtn);
    hide(duplicateCourseBtn);
  }
  
  setError(formError, '');
  showCourseModal();
  courseForm.name.focus();
}

function closeEditor() {
  hideCourseModal();
  state.editingGroupName = null;
}

// 倒计时刷新
function updateSessionBadge() {
  const expiresAt = state.session?.expiresAt;
  if (!expiresAt) {
    sessionBadge.textContent = '连接正常';
    sessionCountdown.textContent = '无过期上限';
    return;
  }
  const remainingMs = new Date(expiresAt).getTime() - Date.now();
  if (remainingMs <= 0) {
    sessionBadge.textContent = '连接已过期';
    sessionBadge.className = 'badge bg-danger';
    sessionCountdown.textContent = '请安全退出并在手机端重新开启';
    return;
  }
  const minutes = Math.floor(remainingMs / 60000);
  const seconds = Math.floor((remainingMs % 60000) / 1000);

  if (minutes < 5) {
    sessionBadge.textContent = '连接即将断开';
    sessionBadge.className = 'badge bg-warning';
  } else {
    sessionBadge.textContent = '安全连接中';
    sessionBadge.className = 'badge bg-success';
  }
  sessionCountdown.textContent = minutes > 0 ? `倒计时 ${minutes} 分 ${seconds} 秒` : `倒计时 ${seconds} 秒`;
}

function startSessionCountdown() {
  if (state.sessionTimerId) {
    clearInterval(state.sessionTimerId);
  }
  updateSessionBadge();
  state.sessionTimerId = setInterval(updateSessionBadge, 1000);
}

// 载入全部同步数据
async function loadEditorData(options = {}) {
  const { silent = false, notifyRefresh = false } = options;
  if (!silent) {
    setLoading(true, '同步手机端数据中…');
  }
  try {
    const [meta, coursePayload, session] = await Promise.all([
      api('/api/v1/meta'),
      api('/api/v1/courses'),
      api('/api/v1/session'),
    ]);
    state.meta = meta;
    state.courses = coursePayload.courses || [];
    state.session = session;

    if (!state.viewWeek || state.viewWeek < 1) {
      state.viewWeek = meta.currentWeek;
    }
    state.viewWeek = Math.min(state.viewWeek, meta.semesterWeekCount);

    profileName.textContent = session.profileName || meta.profileName || '当前课表';
    fillWeekPicker();
    updateWeekLabel();
    renderGrid();
    renderCoursesTable();
    renderDashboard();
    renderBackupView();
    startSessionCountdown();

    if (notifyRefresh) {
      showToast('数据刷新成功，已与手机端同步', 'success');
      addActivityLog('数据刷新', '拉取并同步了手机端最新数据');
    }
  } catch (error) {
    showToast('同步手机数据失败: ' + error.message, 'error');
    throw error;
  } finally {
    if (!silent) {
      setLoading(false);
    }
  }
}

async function enterEditor() {
  hide(loginView);
  show(editorView);
  await loadEditorData();
}

async function verifyPinAndEnter(pin) {
  const result = await api('/api/v1/auth/verify', {
    method: 'POST',
    body: JSON.stringify({ pin }),
  });
  state.token = result.token;
  state.pin = pin;
  sessionStorage.setItem('lanEditToken', state.token);
  sessionStorage.setItem('lanEditPin', pin);
  await enterEditor();
  addActivityLog('登录成功', '通过 PIN 验证连接后台');
}

function stripPinFromUrl() {
  const url = new URL(window.location.href);
  if (!url.searchParams.has('pin')) {
    return;
  }
  url.searchParams.delete('pin');
  const cleaned = `${url.pathname}${url.search}${url.hash}`;
  window.history.replaceState({}, '', cleaned || '/');
}

// 导航栏 Tab 切换
navItems.forEach(item => {
  item.addEventListener('click', () => {
    const tabName = item.getAttribute('data-tab');
    setViewTab(tabName);
  });
});

function setViewTab(tabName) {
  state.activeTab = tabName;
  syncTabsUI();
}

function syncTabsUI() {
  navItems.forEach(btn => {
    if (btn.getAttribute('data-tab') === state.activeTab) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  tabPanels.forEach(panel => {
    if (panel.id === `${state.activeTab}-panel`) {
      panel.classList.remove('hidden');
    } else {
      panel.classList.add('hidden');
    }
  });

  const titles = {
    overview: '控制台概览',
    timetable: '课表网格',
    courses: '课程库管理',
    backup: '导入与备份',
  };
  pageTitle.textContent = titles[state.activeTab] || '局域网控制台';
}

// 事件侦听器
loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  setError(loginError, '');
  try {
    const pin = document.getElementById('pin-input').value.trim();
    await verifyPinAndEnter(pin);
  } catch (error) {
    setError(loginError, error.message);
    showToast(error.message, 'error');
  }
});

document.getElementById('logout-btn').addEventListener('click', () => {
  addActivityLog('安全退出', '主动断开连接');
  state.token = '';
  state.pin = '';
  sessionStorage.removeItem('lanEditToken');
  sessionStorage.removeItem('lanEditPin');
  if (state.sessionTimerId) {
    clearInterval(state.sessionTimerId);
    state.sessionTimerId = null;
  }
  hide(editorView);
  show(loginView);
  showToast('已退出局域网编辑', 'info');
});

document.getElementById('refresh-btn').addEventListener('click', () => {
  loadEditorData({ silent: true, notifyRefresh: true }).catch(() => {});
});

if (syncPhoneWeekBtn) {
  syncPhoneWeekBtn.addEventListener('click', async () => {
    try {
      setLoading(true, '正在同步手机当前周…');
      await api('/api/v1/session', {
        method: 'PATCH',
        body: JSON.stringify({ currentWeek: state.viewWeek }),
      });
      showToast(`已将手机当前周设为第 ${state.viewWeek} 周`, 'success');
      addActivityLog('同步当前周', `手机当前周 → 第 ${state.viewWeek} 周`);
      await loadEditorData({ silent: true });
    } catch (error) {
      showToast(error.message, 'error');
    } finally {
      setLoading(false);
    }
  });
}

function handleSpreadsheetFile(file) {
  if (!file) return;
  const lower = file.name.toLowerCase();
  if (!lower.endsWith('.csv') && !lower.endsWith('.xlsx')) {
    showToast('请选择 .csv 或 .xlsx 文件', 'error');
    return;
  }
  selectedSpreadsheetFile = file;
  spreadsheetSelectedFilename.textContent = `已选: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
  show(spreadsheetSelectedFilename);
  btnImportSpreadsheet.disabled = false;
}

if (spreadsheetDropZone) {
  spreadsheetDropZone.addEventListener('click', () => spreadsheetFileInput?.click());
  spreadsheetFileInput?.addEventListener('change', (e) => {
    handleSpreadsheetFile(e.target.files[0]);
  });
  spreadsheetDropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    spreadsheetDropZone.classList.add('dragover');
  });
  ['dragleave', 'dragend'].forEach((type) => {
    spreadsheetDropZone.addEventListener(type, () => {
      spreadsheetDropZone.classList.remove('dragover');
    });
  });
  spreadsheetDropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    spreadsheetDropZone.classList.remove('dragover');
    if (e.dataTransfer.files.length) {
      handleSpreadsheetFile(e.dataTransfer.files[0]);
    }
  });
}

btnImportSpreadsheet?.addEventListener('click', async () => {
  if (!selectedSpreadsheetFile) return;
  const replace = spreadsheetReplaceExisting?.checked === true;
  if (replace && !window.confirm('覆盖模式将替换手机端现有全部课程，确定继续？')) {
    return;
  }
  try {
    setLoading(true, '正在解析并导入表格…');
    const contentBase64 = await readFileAsBase64(selectedSpreadsheetFile);
    const result = await api('/api/v1/import/spreadsheet', {
      method: 'POST',
      body: JSON.stringify({
        fileName: selectedSpreadsheetFile.name,
        contentBase64,
        replaceExisting: replace,
      }),
    });
    const lines = [
      `成功导入 ${result.importedCount ?? 0} 条课程`,
      `格式: ${result.format ?? '-'}`,
    ];
    if (result.warnings?.length) {
      lines.push('警告:', ...result.warnings.map((w) => `· ${w}`));
    }
    spreadsheetImportResult.textContent = lines.join('\n');
    show(spreadsheetImportResult);
    showToast(`表格导入完成：${result.importedCount ?? 0} 门课`, 'success');
    addActivityLog('表格导入', `导入 ${result.importedCount ?? 0} 门课 (${replace ? '覆盖' : '合并'})`);
    selectedSpreadsheetFile = null;
    btnImportSpreadsheet.disabled = true;
    await loadEditorData();
  } catch (error) {
    showToast('表格导入失败: ' + error.message, 'error');
  } finally {
    setLoading(false);
  }
});

function handleMergeBackupFile(file) {
  if (!file || !file.name.toLowerCase().endsWith('.json')) {
    showToast('请选择 .json 备份文件', 'error');
    return;
  }
  const reader = new FileReader();
  reader.onload = () => {
    selectedMergeFileContent = String(reader.result);
    mergeSelectedFilename.textContent = `已选: ${file.name}`;
    show(mergeSelectedFilename);
    if (btnImportMerge) btnImportMerge.disabled = false;
  };
  reader.onerror = () => showToast('读取文件失败', 'error');
  reader.readAsText(file, 'utf-8');
}

if (mergeDropZone) {
  mergeDropZone.addEventListener('click', () => mergeFileInput?.click());
  mergeFileInput?.addEventListener('change', (e) => handleMergeBackupFile(e.target.files[0]));
  mergeDropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    mergeDropZone.classList.add('dragover');
  });
  ['dragleave', 'dragend'].forEach((type) => {
    mergeDropZone.addEventListener(type, () => mergeDropZone.classList.remove('dragover'));
  });
  mergeDropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    mergeDropZone.classList.remove('dragover');
    if (e.dataTransfer.files.length) handleMergeBackupFile(e.dataTransfer.files[0]);
  });
}

btnImportMerge?.addEventListener('click', async () => {
  if (!selectedMergeFileContent) return;
  try {
    setLoading(true, '正在合并导入…');
    const result = await api('/api/v1/import/merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: selectedMergeFileContent,
    });
    const merged = result.mergedCount ?? 0;
    if (mergeImportResult) {
      mergeImportResult.textContent = `合并完成，处理 ${merged} 门课程（与现有课表智能合并）`;
      show(mergeImportResult);
    }
    showToast(`合并导入完成`, 'success');
    addActivityLog('合并导入', `合并备份课程 ${merged} 门`);
    selectedMergeFileContent = null;
    if (btnImportMerge) btnImportMerge.disabled = true;
    await loadEditorData();
  } catch (error) {
    showToast('合并导入失败: ' + error.message, 'error');
  } finally {
    setLoading(false);
  }
});

btnBatchDeleteCourses?.addEventListener('click', async () => {
  const ids = [...selectedCourseIds];
  if (!ids.length) return;
  if (!window.confirm(`确定批量删除选中的 ${ids.length} 个上课时间段记录吗？`)) return;
  try {
    setLoading(true, '正在批量删除…');
    const result = await api('/api/v1/courses/batch-delete', {
      method: 'POST',
      body: JSON.stringify({ ids }),
    });
    showToast(`已删除 ${result.deletedCount ?? 0} 条`, 'success');
    addActivityLog('批量删除', `删除 ${result.deletedCount ?? 0} 条课程记录`);
    selectedCourseIds.clear();
    await loadEditorData({ silent: true });
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    setLoading(false);
  }
});

document.getElementById('prev-week-btn').addEventListener('click', () => {
  setViewWeek(state.viewWeek - 1);
});

document.getElementById('next-week-btn').addEventListener('click', () => {
  setViewWeek(state.viewWeek + 1);
});

weekPicker.addEventListener('change', () => {
  setViewWeek(Number(weekPicker.value));
});

courseSearch.addEventListener('input', () => {
  state.courseSearch = courseSearch.value;
  renderCoursesTable();
});

filterNature.addEventListener('change', () => {
  state.filterNature = filterNature.value;
  renderCoursesTable();
});

document.getElementById('quick-add-btn').addEventListener('click', () => {
  state.activeTab = 'courses';
  syncTabsUI();
  openEditor(null);
});

document.getElementById('btn-add-course').addEventListener('click', () => openEditor(null));
document.getElementById('cancel-course-btn').addEventListener('click', closeEditor);
document.getElementById('close-modal-x').addEventListener('click', closeEditor);

modal.addEventListener('click', (event) => {
  if (!window.bootstrap?.Modal && event.target === modal) {
    closeEditor();
  }
});

// 添加动态 slots field 项
btnAddSlotField.addEventListener('click', () => {
  addSlotField();
});

// 整个课程组的删除操作
deleteCourseBtn.addEventListener('click', async () => {
  if (!state.editingGroupName) return;
  if (!window.confirm(`确定要彻底删除课程《${state.editingGroupName}》的全部时间段吗？`)) return;
  try {
    setLoading(true, '正在删除课程…');
    const toDelete = state.courses.filter(c => c.name === state.editingGroupName);
    for (const c of toDelete) {
      await api(`/api/v1/courses/${encodeURIComponent(c.id)}`, {
        method: 'DELETE',
      });
    }
    closeEditor();
    showToast('课程已删除', 'success');
    addActivityLog('删除课程', `删除了课程 [${state.editingGroupName}]`);
    await loadEditorData({ silent: true });
  } catch (error) {
    setError(formError, error.message);
    showToast(error.message, 'error');
  } finally {
    setLoading(false);
  }
});

// 整个课程组的复制操作
duplicateCourseBtn.addEventListener('click', async () => {
  const name = courseForm.name.value.trim() + ' (副本)';
  const shortName = courseForm.shortName.value.trim() || null;
  const courseNature = courseForm.courseNature.value;
  const color = colorInput.value;
  const note = courseForm.note.value.trim() || null;

  if (!name) {
    setError(formError, '请填写课程名称');
    return;
  }

  const slotCards = scheduleSlotsContainer.querySelectorAll('.slot-card');
  const slots = [];

  for (const card of slotCards) {
    const dayOfWeek = Number(card.querySelector('.field-slot-day').value);
    const startSection = Number(card.querySelector('.field-slot-startSection').value);
    const endSection = Number(card.querySelector('.field-slot-endSection').value);
    const startWeek = Number(card.querySelector('.field-slot-startWeek').value);
    const endWeek = Number(card.querySelector('.field-slot-endWeek').value);
    const isOddWeek = card.querySelector('.field-slot-isOddWeek').checked;
    const isEvenWeek = card.querySelector('.field-slot-isEvenWeek').checked;
    const teacher = card.querySelector('.field-slot-teacher').value.trim();
    const location = card.querySelector('.field-slot-location').value.trim();

    if (endSection < startSection) {
      setError(formError, '结束节次不能小于开始节次');
      return;
    }
    if (endWeek < startWeek) {
      setError(formError, '结束周次不能小于开始周次');
      return;
    }

    slots.push({ dayOfWeek, startSection, endSection, startWeek, endWeek, isOddWeek, isEvenWeek, teacher, location });
  }

  if (slots.length === 0) {
    setError(formError, '课程必须包含至少一个上课时间段');
    return;
  }

  try {
    setLoading(true, '正在复制创建课程…');
    for (const slot of slots) {
      const payload = {
        name,
        shortName,
        courseNature,
        color,
        note,
        dayOfWeek: slot.dayOfWeek,
        startSection: slot.startSection,
        endSection: slot.endSection,
        startWeek: slot.startWeek,
        endWeek: slot.endWeek,
        isOddWeek: slot.isOddWeek,
        isEvenWeek: slot.isEvenWeek,
        teacher: slot.teacher,
        location: slot.location
      };
      await api('/api/v1/courses', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
    }

    closeEditor();
    showToast('课程复制成功', 'success');
    addActivityLog('复制课程', `复制并新建了课程组 [${name}]`);
    await loadEditorData({ silent: true });
  } catch (error) {
    setError(formError, error.message);
    showToast(error.message, 'error');
  } finally {
    setLoading(false);
  }
});

// 保存表单（多 slots 协同写入）
courseForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  setError(formError, '');

  const name = courseForm.name.value.trim();
  const shortName = courseForm.shortName.value.trim() || null;
  const courseNature = courseForm.courseNature.value;
  const color = colorInput.value;
  const note = courseForm.note.value.trim() || null;

  if (!name) {
    setError(formError, '请填写课程名称');
    return;
  }

  const slotCards = scheduleSlotsContainer.querySelectorAll('.slot-card');
  const slots = [];

  for (const card of slotCards) {
    const slotId = card.dataset.id || '';
    const dayOfWeek = Number(card.querySelector('.field-slot-day').value);
    const startSection = Number(card.querySelector('.field-slot-startSection').value);
    const endSection = Number(card.querySelector('.field-slot-endSection').value);
    const startWeek = Number(card.querySelector('.field-slot-startWeek').value);
    const endWeek = Number(card.querySelector('.field-slot-endWeek').value);
    const isOddWeek = card.querySelector('.field-slot-isOddWeek').checked;
    const isEvenWeek = card.querySelector('.field-slot-isEvenWeek').checked;
    const teacher = card.querySelector('.field-slot-teacher').value.trim();
    const location = card.querySelector('.field-slot-location').value.trim();
    const weekExpression = card.querySelector('.field-slot-weekExpression')?.value.trim() || '';
    const suspendedWeekExpression =
      card.querySelector('.field-slot-suspendedWeekExpression')?.value.trim() || '';

    if (endSection < startSection) {
      setError(formError, '结束节次不能小于开始节次');
      return;
    }
    if (!weekExpression && endWeek < startWeek) {
      setError(formError, '结束周次不能小于开始周次');
      return;
    }

    const maxSection = state.meta?.sectionCount || state.meta?.sections?.length || 12;
    if (startSection < 1 || endSection > maxSection) {
      setError(formError, `节次范围应在 1-${maxSection} 之间`);
      return;
    }

    const slotEntry = {
      id: slotId,
      dayOfWeek,
      startSection,
      endSection,
      startWeek,
      endWeek,
      isOddWeek,
      isEvenWeek,
      teacher,
      location,
    };
    if (weekExpression) {
      slotEntry.weekExpression = weekExpression;
    }
    if (suspendedWeekExpression) {
      slotEntry.suspendedWeekExpression = suspendedWeekExpression;
    }
    slots.push(slotEntry);
  }

  if (slots.length === 0) {
    setError(formError, '至少需要保留一个上课时间段');
    return;
  }

  try {
    setLoading(true, '正在保存数据到手机端…');

    const buildSlotPayload = (slot) => ({
      id: slot.id || undefined,
      name,
      shortName,
      courseNature,
      color,
      note,
      dayOfWeek: slot.dayOfWeek,
      startSection: slot.startSection,
      endSection: slot.endSection,
      startWeek: slot.startWeek,
      endWeek: slot.endWeek,
      isOddWeek: slot.isOddWeek,
      isEvenWeek: slot.isEvenWeek,
      teacher: slot.teacher,
      location: slot.location,
      ...(slot.weekExpression ? { weekExpression: slot.weekExpression } : {}),
      ...(slot.suspendedWeekExpression
        ? { suspendedWeekExpression: slot.suspendedWeekExpression }
        : {}),
    });

    await api('/api/v1/courses/group', {
      method: 'PUT',
      body: JSON.stringify({
        originalName: state.editingGroupName || undefined,
        slots: slots.map(buildSlotPayload),
      }),
    });

    if (state.editingGroupName) {
      showToast('课程修改已保存', 'success');
      addActivityLog('更新课程', `更新了课程 [${name}] 的上课安排`);
    } else {
      showToast('新课程已成功创建', 'success');
      addActivityLog('新建课程', `创建了新课程 [${name}]`);
    }

    closeEditor();
    await loadEditorData({ silent: true });
  } catch (error) {
    setError(formError, error.message);
    showToast(error.message, 'error');
  } finally {
    setLoading(false);
  }
});

// 快捷键绑定
document.addEventListener('keydown', (event) => {
  if (modal.classList.contains('show')) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeEditor();
    }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
      event.preventDefault();
      courseForm.requestSubmit();
    }
  }
});

// 页面初始化自举引导
async function bootstrap() {
  renderActivityLog();
  const params = new URLSearchParams(window.location.search);
  const urlToken = params.get('token');
  if (urlToken) {
    state.token = urlToken;
    sessionStorage.setItem('lanEditToken', urlToken);
  }

  const urlPin = params.get('pin');
  if (urlPin) {
    state.pin = urlPin.trim();
    sessionStorage.setItem('lanEditPin', urlPin.trim());
  }

  if (state.token) {
    try {
      await enterEditor();
      return;
    } catch (_) {
      state.token = '';
      sessionStorage.removeItem('lanEditToken');
    }
  }

  if (urlPin) {
    setLoading(true, '正在自动进行 PIN 码验证连接…');
    try {
      await verifyPinAndEnter(urlPin.trim());
      stripPinFromUrl();
      showToast('登录成功', 'success');
      return;
    } catch (error) {
      setError(loginError, error.message);
      showToast(error.message, 'error');
    } finally {
      setLoading(false);
    }
  }
}

bootstrap();
