import {defineTheme} from '@astryxdesign/core/theme';
import {neutralTheme} from '@astryxdesign/theme-neutral/built';

export const memoryosTheme = defineTheme({
  name: 'memoryos',
  extends: neutralTheme,
  typography: {
    body: {family: 'system-ui', fallbacks: '-apple-system, BlinkMacSystemFont, sans-serif'},
    heading: {family: 'system-ui', fallbacks: '-apple-system, BlinkMacSystemFont, sans-serif'},
  },
  tokens: {
    '--font-family-body': '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    '--font-family-heading': '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    '--color-background-surface': 'rgb(255 255 255)',
    '--color-background-body': 'rgb(247 247 245)',
    '--color-background-inverted': 'rgb(40 40 40)',
    '--color-text-primary': 'rgb(40 40 40)',
    '--color-text-secondary': 'rgb(107 107 107)',
    '--color-border': 'rgb(225 225 225)',
    '--color-border-emphasized': 'rgb(197 197 197)',
    '--color-accent': 'rgb(40 40 40)',
    '--color-text-accent': 'rgb(40 40 40)',
    '--color-icon-accent': 'rgb(40 40 40)',
    '--color-on-accent': 'rgb(255 255 255)',
    '--color-overlay': 'rgb(0 0 0 / .32)',
  },
});
