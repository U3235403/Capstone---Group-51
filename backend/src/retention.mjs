// Calendar months, clamped to the target month's last day; UTC throughout.
export function retentionDeadline(date) {
 const d=new Date(date);if(!Number.isFinite(d.getTime()))throw Error('Invalid retention date');
 const day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+3);
 const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();
 d.setUTCDate(Math.min(day,last));return d;
}
