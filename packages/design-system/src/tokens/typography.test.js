import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { typography } from './typography.js';

describe('body copy type styles', () => {
  it('uses one 16px size for paragraph / description copy', () => {
    assert.equal(typography.styles.body.fontSize, '16px');
    assert.equal(typography.styles.bodyCopy.fontSize, '16px');
    assert.equal(typography.styles.bodyCopy.fontSize, typography.styles.body.fontSize);
  });

  it('gives body copy open reading line-height', () => {
    assert.equal(typography.lineHeights.reading, 1.65);
    assert.equal(typography.styles.body.lineHeight, 1.65);
    assert.equal(typography.styles.bodyCopy.lineHeight, 1.65);
    assert.equal(typography.styles.bodyLarge.lineHeight, 1.65);
    assert.equal(typography.styles.bodySmall.lineHeight, 1.65);
  });
});
