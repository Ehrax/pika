export const runWithConcurrencyLimit = async <T, R>(
  items: T[],
  maxParallel: number,
  work: (item: T) => Promise<R>
) => {
  let running = 0;
  const queue: (() => void)[] = [];

  const acquire = () =>
    running < maxParallel
      ? (running++, Promise.resolve())
      : new Promise<void>((resolve) => queue.push(resolve));

  const release = () => {
    running--;
    const next = queue.shift();
    if (next) {
      running++;
      next();
    }
  };

  return Promise.allSettled(
    items.map(async (item) => {
      await acquire();
      try {
        return await work(item);
      } finally {
        release();
      }
    })
  );
};
