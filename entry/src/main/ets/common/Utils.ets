/**
 * 通用工具：时间格式化等。
 */

/** 补零 */
function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

/** 时间戳 → MM-DD HH:mm:ss */
export function formatTime(timestamp: number): string {
  const date: Date = new Date(timestamp);
  const month: string = pad2(date.getMonth() + 1);
  const day: string = pad2(date.getDate());
  const hour: string = pad2(date.getHours());
  const minute: string = pad2(date.getMinutes());
  const second: string = pad2(date.getSeconds());
  return `${month}-${day} ${hour}:${minute}:${second}`;
}

/** 时间戳 → HH:mm:ss */
export function formatClock(timestamp: number): string {
  const date: Date = new Date(timestamp);
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(date.getSeconds())}`;
}
