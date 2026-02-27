// Pure formatting utilities for business hours preview text.
// No DOM interaction — safe to unit test independently.

export function formatBusinessHours(windows, weekdayAbbr, everyDayLabel) {
  if (!windows.length) return null

  const groups = groupByTime(windows)
  return groups.map(({ days, opens, closes }) => {
    const dayStr = formatWeekdayRange(days.sort((a, b) => a - b), weekdayAbbr, everyDayLabel)
    return `${dayStr} ${opens}–${closes}`
  }).join(", ")
}

export function groupByTime(windows) {
  const map = new Map()
  windows.forEach(({ weekday, opens, closes }) => {
    const key = `${opens}|${closes}`
    if (!map.has(key)) map.set(key, { opens, closes, days: [] })
    map.get(key).days.push(weekday)
  })
  return Array.from(map.values())
}

export function formatWeekdayRange(days, abbr, everyDay) {
  const monFri = [ 1, 2, 3, 4, 5 ]
  const monSat = [ 1, 2, 3, 4, 5, 6 ]
  const all    = [ 0, 1, 2, 3, 4, 5, 6 ]
  if (arraysEqual(days, monFri)) return `${abbr[1]}–${abbr[5]}`
  if (arraysEqual(days, monSat)) return `${abbr[1]}–${abbr[6]}`
  if (arraysEqual(days, all))    return everyDay
  return days.map(d => abbr[d]).join(", ")
}

function arraysEqual(a, b) {
  if (a.length !== b.length) return false
  return a.every((v, i) => v === b[i])
}
