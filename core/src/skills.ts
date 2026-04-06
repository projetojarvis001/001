
// Skills loader — carrega contexto WPS/Grupo Wagner automaticamente
import fs from 'fs';
import path from 'path';

export function loadSkills(): string {
  const skillsDir = '/host_jarvis/skills';
  if (!fs.existsSync(skillsDir)) return '';
  const skills = fs.readdirSync(skillsDir)
    .filter(f => f.endsWith('.json'))
    .map(f => {
      try {
        const s = JSON.parse(fs.readFileSync(path.join(skillsDir, f), 'utf8'));
        return `[${s.name}]: ${s.context || JSON.stringify(s).slice(0, 200)}`;
      } catch { return ''; }
    })
    .filter(Boolean)
    .join('\n');
  return skills ? `\n\nCONTEXTO DO NEGÓCIO:\n${skills}` : '';
}
