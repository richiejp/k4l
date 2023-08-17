# About

This container can be used to configure an NFS client or server. It
also contains Scapy and some other network tools. The idea is to test
NFS by crafting packets with Scapy.

NFS has its own test suites however Scapy is a general purpose
tool. So in theory this has advantages if we are interested in more
than one protocol.

# Notes

## CVE-2022-43945

### Overview

[Description:](https://nvd.nist.gov/vuln/detail/CVE-2022-43945)

> The Linux kernel NFSD implementation prior to versions 5.19.17 and
> 6.0.2 are vulnerable to buffer overflow. NFSD tracks the number of
> pages held by each NFSD thread by combining the receive and send
> buffers of a remote procedure call (RPC) into a single array of
> pages. A client can force the send buffer to shrink by sending an RPC
> message over TCP with garbage data added at the end of the
> message. The RPC message with garbage data is still correctly formed
> according to the specification and is passed forward to
> handlers. Vulnerable code in NFSD is not expecting the oversized
> request and writes beyond the allocated buffer space.

[Fixes](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f90497a16e434c2211c66e3de8e77b17868382b8)

```
f90497a16e434c2211c66e3de8e77b17868382b8
Author:     Linus Torvalds <torvalds@linux-foundation.org>
AuthorDate: Mon Oct 3 20:07:15 2022 -0700
Commit:     Linus Torvalds <torvalds@linux-foundation.org>
CommitDate: Mon Oct 3 20:07:15 2022 -0700

Parent:     3497640a80d7 Merge tag 'erofs-for-6.1-rc1' of git://git.kernel.org/pub/scm/linux/kernel/git/xiang/erofs
Parent:     895ddf5ed4c5 nfsd: extra checks when freeing delegation stateids
Contained:  master
Follows:    v6.0 (558)
Precedes:   v6.1-rc1 (11730)

Merge tag 'nfsd-6.1' of git://git.kernel.org/pub/scm/linux/kernel/git/cel/linux

Pull nfsd updates from Chuck Lever:
 "This release is mostly bug fixes, clean-ups, and optimizations.

  One notable set of fixes addresses a subtle buffer overflow issue that
  occurs if a small RPC Call message arrives in an oversized RPC record.
  This is only possible on a framed RPC transport such as TCP.

  Because NFSD shares the receive and send buffers in one set of pages,
  an oversized RPC record steals pages from the send buffer that will be
  used to construct the RPC Reply message. NFSD must not assume that a
  full-sized buffer is always available to it; otherwise, it will walk
  off the end of the send buffer while constructing its reply.

  ...
```

Possibly these are the fixes mentioned in the merge commit:

- fa6be9cc6e80 NFSD: Protect against send buffer overflow in NFSv3 READ
- 401bc1f90874 NFSD: Protect against send buffer overflow in NFSv2 READ
- 640f87c190e0 NFSD: Protect against send buffer overflow in NFSv3 READDIR
- 00b4492686e0 NFSD: Protect against send buffer overflow in NFSv2 READDIR

These could be related

- 1242a87da0d8 SUNRPC: Fix svcxdr_init_encode's buflen calculation
- 90bfc37b5ab9 SUNRPC: Fix svcxdr_init_decode's end-of-buffer calculation

We'll focus on the NFSv3 read fixes

```
$  git show fa6be9cc6e80
commit fa6be9cc6e80ec79892ddf08a8c10cabab9baf38
Author: Chuck Lever <chuck.lever@oracle.com>
Date:   Thu Sep 1 15:10:24 2022 -0400

    NFSD: Protect against send buffer overflow in NFSv3 READ

    Since before the git era, NFSD has conserved the number of pages
    held by each nfsd thread by combining the RPC receive and send
    buffers into a single array of pages. This works because there are
    no cases where an operation needs a large RPC Call message and a
    large RPC Reply at the same time.

    Once an RPC Call has been received, svc_process() updates
    svc_rqst::rq_res to describe the part of rq_pages that can be
    used for constructing the Reply. This means that the send buffer
    (rq_res) shrinks when the received RPC record containing the RPC
    Call is large.

    A client can force this shrinkage on TCP by sending a correctly-
    formed RPC Call header contained in an RPC record that is
    excessively large. The full maximum payload size cannot be
    constructed in that case.

    Cc: <stable@vger.kernel.org>
    Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
    Reviewed-by: Jeff Layton <jlayton@kernel.org>
    Signed-off-by: Chuck Lever <chuck.lever@oracle.com>

diff --git a/fs/nfsd/nfs3proc.c b/fs/nfsd/nfs3proc.c
index 7a159785499a..5b1e771238b3 100644
--- a/fs/nfsd/nfs3proc.c
+++ b/fs/nfsd/nfs3proc.c
@@ -150,7 +150,6 @@ nfsd3_proc_read(struct svc_rqst *rqstp)
 {
        struct nfsd3_readargs *argp = rqstp->rq_argp;
        struct nfsd3_readres *resp = rqstp->rq_resp;
-       u32 max_blocksize = svc_max_payload(rqstp);
        unsigned int len;
        int v;

@@ -159,7 +158,8 @@ nfsd3_proc_read(struct svc_rqst *rqstp)
                                (unsigned long) argp->count,
                                (unsigned long long) argp->offset);

-       argp->count = min_t(u32, argp->count, max_blocksize);
+       argp->count = min_t(u32, argp->count, svc_max_payload(rqstp));
+       argp->count = min_t(u32, argp->count, rqstp->rq_res.buflen);
        if (argp->offset > (u64)OFFSET_MAX)
                argp->offset = (u64)OFFSET_MAX;
        if (argp->offset + argp->count > (u64)OFFSET_MAX)
```

```
$ git show 640f87c
commit 640f87c190e0d1b2a0fcb2ecf6d2cd53b1c41991
Author: Chuck Lever <chuck.lever@oracle.com>
Date:   Thu Sep 1 15:10:12 2022 -0400

    NFSD: Protect against send buffer overflow in NFSv3 READDIR

    ...

    Thanks to Aleksi Illikainen and Kari Hulkko for uncovering this
    issue.

    Reported-by: Ben Ronallo <Benjamin.Ronallo@synopsys.com>
    Cc: <stable@vger.kernel.org>
    Signed-off-by: Chuck Lever <chuck.lever@oracle.com>
    Reviewed-by: Jeff Layton <jlayton@kernel.org>
    Signed-off-by: Chuck Lever <chuck.lever@oracle.com>

diff --git a/fs/nfsd/nfs3proc.c b/fs/nfsd/nfs3proc.c
index a41cca619338..7a159785499a 100644
--- a/fs/nfsd/nfs3proc.c
+++ b/fs/nfsd/nfs3proc.c
@@ -563,13 +563,14 @@ static void nfsd3_init_dirlist_pages(struct svc_rqst *rqstp,
 {
        struct xdr_buf *buf = &resp->dirlist;
        struct xdr_stream *xdr = &resp->xdr;
-
-       count = clamp(count, (u32)(XDR_UNIT * 2), svc_max_payload(rqstp));
+       unsigned int sendbuf = min_t(unsigned int, rqstp->rq_res.buflen,
+                                    svc_max_payload(rqstp));

        memset(buf, 0, sizeof(*buf));

        /* Reserve room for the NULL ptr & eof flag (-2 words) */
-       buf->buflen = count - XDR_UNIT * 2;
+       buf->buflen = clamp(count, (u32)(XDR_UNIT * 2), sendbuf);
+       buf->buflen -= XDR_UNIT * 2;
        buf->pages = rqstp->rq_next_page;
        rqstp->rq_next_page += (buf->buflen + PAGE_SIZE - 1) >> PAGE_SHIFT;
```

### Investigation

The struct which are `rq_arg` and `rq_res`

```c
struct xdr_buf {
	struct kvec	head[1],	/* RPC header + non-page data */
			tail[1];	/* Appended after page data */

	struct bio_vec	*bvec;
	struct page **	pages;		/* Array of pages */
	unsigned int	page_base,	/* Start of page data */
			page_len,	/* Length of page data */
			flags;		/* Flags for data disposition */
#define XDRBUF_READ		0x01		/* target of file read */
#define XDRBUF_WRITE		0x02		/* source of file write */
#define XDRBUF_SPARSE_PAGES	0x04		/* Page array is sparse */

	unsigned int	buflen,		/* Total length of storage buffer */
			len;		/* Length of XDR encoded message */
};
```

in

```c
/*
 * The context of a single thread, including the request currently being
 * processed.
 */
struct svc_rqst {
    ...
	struct xdr_buf		rq_arg;
	struct xdr_stream	rq_arg_stream;
	struct xdr_stream	rq_res_stream;
	struct page		*rq_scratch_page;
	struct xdr_buf		rq_res;
	struct page		*rq_pages[RPCSVC_MAXPAGES + 1];
	struct page *		*rq_respages;	/* points into rq_pages */
	struct page *		*rq_next_page; /* next reply page to use */
	struct page *		*rq_page_end;  /* one past the last page */

	struct pagevec		rq_pvec;
	struct kvec		rq_vec[RPCSVC_MAXPAGES]; /* generally useful.. */
	struct bio_vec		rq_bvec[RPCSVC_MAXPAGES];
    ...
	void *			rq_argp;	/* decoded arguments */
	void *			rq_resp;	/* xdr'd results */
    ...
```

- On TCP the record marker is read in `svc_tcp_recvfrom` with `savc_tcp_read_marker`.
 - `svc_tcp_read_msg` reads the rest of the record (on a good day)
   - it sets `rqstp->rq_respages` to the last page it used
   - `rgstp->rq_arg.len = svsk->sk_datalen` and returns `rqstp->rq_arg.len`
 - `rqstp->rq_arg.page_len > 0` if `rq_arg.len` doesn't fit in the head

- `svc_process`
 - set `rq_res.pages` to `rq_respages[1]`
 - `nfsd_dispatch` -> `svcxdr_init_decode`
   - `rq_res->buflen = PAGE_SIZE * (rqstp->rq_page_end - buf->pages);`

The fix then makes sense as it adds `rq_res->buflen` into the mix.
