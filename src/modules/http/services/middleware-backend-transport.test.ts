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
});
