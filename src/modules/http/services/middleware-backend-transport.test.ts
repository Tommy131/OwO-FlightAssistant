import { describe, expect, it, vi } from 'vitest';
import { MiddlewareHttpService } from './middleware-http-service';
import { middlewareBackendTransport } from './middleware-backend-transport';

describe('middlewareBackendTransport', () => {
  it('saves landing reports in the landing-report collection', async () => {
    const post = vi.spyOn(MiddlewareHttpService, 'post').mockResolvedValue({} as never);

    await middlewareBackendTransport.saveRecord('landingReport', 'lr-1', {
      id: 'lr-1',
      updatedAt: 42,
    });

    expect(post).toHaveBeenCalledWith('/api/v1/landing-reports/save', {
      body: { id: 'lr-1', record: { id: 'lr-1', updatedAt: 42 } },
    });
    expect(post).not.toHaveBeenCalledWith('/api/v1/briefings/save', expect.anything());
    post.mockRestore();
  });

  it('lists landing reports from the landing-report collection', async () => {
    const get = vi.spyOn(MiddlewareHttpService, 'get').mockResolvedValue({
      objectBody: { records: [] },
    } as never);

    await middlewareBackendTransport.listRecords('landingReport');

    expect(get).toHaveBeenCalledWith('/api/v1/landing-reports/list');
    expect(get).not.toHaveBeenCalledWith('/api/v1/briefings/list');
    get.mockRestore();
  });

  it('deletes landing reports from the landing-report collection', async () => {
    const post = vi.spyOn(MiddlewareHttpService, 'post').mockResolvedValue({} as never);

    await middlewareBackendTransport.deleteRecord('landingReport', 'lr-1');

    expect(post).toHaveBeenCalledWith('/api/v1/landing-reports/delete', {
      body: { id: 'lr-1' },
    });
    expect(post).not.toHaveBeenCalledWith('/api/v1/briefings/delete', expect.anything());
    post.mockRestore();
  });

  it('round-trips landing-report revisions and tombstones additively', async () => {
    const post = vi.spyOn(MiddlewareHttpService, 'post')
      .mockResolvedValueOnce({ objectBody: { revision: 4 } } as never)
      .mockResolvedValueOnce({
        objectBody: { revision: 5, tombstone: true },
      } as never);
    const get = vi.spyOn(MiddlewareHttpService, 'get').mockResolvedValue({
      objectBody: {
        records: [{ id: 'live' }],
        revisions: { live: 4 },
        tombstones: [{ id: 'gone', revision: 2, deleted: true }],
      },
    } as never);

    await expect(
      middlewareBackendTransport.saveRecord(
        'landingReport',
        'live',
        { id: 'live' },
        { expectedRevision: 3 },
      ),
    ).resolves.toEqual({ revision: 4 });
    await expect(
      middlewareBackendTransport.deleteRecord(
        'landingReport',
        'live',
        { expectedRevision: 4 },
      ),
    ).resolves.toEqual({ revision: 5, deleted: true });
    await expect(
      middlewareBackendTransport.listRecordState?.('landingReport'),
    ).resolves.toEqual({
      records: [{ id: 'live' }],
      revisions: { live: 4 },
      tombstones: [{ id: 'gone', revision: 2, deleted: true }],
    });

    expect(post).toHaveBeenNthCalledWith(1, '/api/v1/landing-reports/save', {
      body: {
        id: 'live',
        record: { id: 'live' },
        expected_revision: 3,
      },
    });
    expect(post).toHaveBeenNthCalledWith(2, '/api/v1/landing-reports/delete', {
      body: { id: 'live', expected_revision: 4 },
    });
    post.mockRestore();
    get.mockRestore();
  });
});
