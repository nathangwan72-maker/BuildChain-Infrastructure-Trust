(define-data-var owner principal tx-sender)

(define-data-var last-project-id uint u0)

(define-map infrastructure-projects
  { id: uint }
  { name: (string-ascii 64),
    owner: principal,
    metadata-url: (string-utf8 128),
    created-at: uint,
    last-updated-at: uint,
    trust-score: uint,
    total-ratings: uint })

(define-map project-ratings
  { id: uint, rater: principal }
  { score: uint })

(define-map project-maintainers
  { id: uint, maintainer: principal }
  { active: bool })

(define-constant err-unauthorized (err u100))

(define-constant err-project-not-found (err u101))

(define-constant err-invalid-score (err u102))

(define-constant err-already-rated (err u103))

(define-constant rating-min u0)

(define-constant rating-max u100)

(define-public (set-owner (new-owner principal))
  (if (is-eq tx-sender (var-get owner))
      (begin
        (var-set owner new-owner)
        (ok true))
      err-unauthorized))

(define-read-only (get-owner)
  (ok (var-get owner)))

(define-read-only (get-last-project-id)
  (ok (var-get last-project-id)))

(define-read-only (get-current-block-height)
  (ok stacks-block-height))

(define-read-only (get-current-block-time)
  (ok (default-to u0 (get-stacks-block-info? time stacks-block-height))))

(define-private (ensure-project-owner (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (if (is-eq tx-sender (get owner project))
        (ok project)
        err-unauthorized)
    err-project-not-found))

(define-read-only (get-project (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok project)
    err-project-not-found))

(define-read-only (get-project-trust-score (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (get trust-score project))
    err-project-not-found))

(define-read-only (get-project-total-ratings (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (get total-ratings project))
    err-project-not-found))

(define-read-only (has-rated (project-id uint) (rater principal))
  (match (map-get? project-ratings { id: project-id, rater: rater }) rating
    (ok true)
    (ok false)))

(define-public (register-project (name (string-ascii 64)) (metadata-url (string-utf8 128)))
  (let
    ((next-id (+ (var-get last-project-id) u1)))
    (begin
      (map-insert infrastructure-projects
        { id: next-id }
        { name: name,
          owner: tx-sender,
          metadata-url: metadata-url,
          created-at: stacks-block-height,
          last-updated-at: stacks-block-height,
          trust-score: u0,
          total-ratings: u0 })
      (var-set last-project-id next-id)
      (ok next-id))))

(define-public (update-project-metadata (project-id uint) (name (string-ascii 64)) (metadata-url (string-utf8 128)))
  (match (ensure-project-owner project-id)
    project
    (begin
      (map-set infrastructure-projects
        { id: project-id }
        { name: name,
          owner: (get owner project),
          metadata-url: metadata-url,
          created-at: (get created-at project),
          last-updated-at: stacks-block-height,
          trust-score: (get trust-score project),
          total-ratings: (get total-ratings project) })
      (ok true))
    err
    (err err)))

(define-public (transfer-project-ownership (project-id uint) (new-owner principal))
  (match (ensure-project-owner project-id)
    project
    (begin
      (map-set infrastructure-projects
        { id: project-id }
        { name: (get name project),
          owner: new-owner,
          metadata-url: (get metadata-url project),
          created-at: (get created-at project),
          last-updated-at: stacks-block-height,
          trust-score: (get trust-score project),
          total-ratings: (get total-ratings project) })
      (ok true))
    err
    (err err)))

(define-public (rate-project (project-id uint) (score uint))
  (if (<= score u100)
      (match (map-get? infrastructure-projects { id: project-id }) project
        (match (map-get? project-ratings { id: project-id, rater: tx-sender }) existing-rating
          err-already-rated
          (let
            ((current-score (get trust-score project))
             (current-total (get total-ratings project))
             (new-total (+ current-total u1))
             (aggregated (+ (* current-score current-total) score))
             (new-score (/ aggregated new-total)))
            (begin
              (map-insert project-ratings
                { id: project-id, rater: tx-sender }
                { score: score })
              (map-set infrastructure-projects
                { id: project-id }
                { name: (get name project),
                  owner: (get owner project),
                  metadata-url: (get metadata-url project),
                  created-at: (get created-at project),
                  last-updated-at: stacks-block-height,
                  trust-score: new-score,
                  total-ratings: new-total })
              (ok new-score))))
        err-project-not-found)
      err-invalid-score))

(define-read-only (get-project-rating-by (project-id uint) (rater principal))
  (match (map-get? project-ratings { id: project-id, rater: rater }) rating
    (ok (get score rating))
    err-project-not-found))

(define-read-only (is-contract-owner (who principal))
  (ok (is-eq who (var-get owner))))

(define-read-only (is-project-owner (project-id uint) (who principal))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (is-eq who (get owner project)))
    err-project-not-found))

(define-read-only (get-project-owner (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (get owner project))
    err-project-not-found))

(define-read-only (get-project-name (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (get name project))
    err-project-not-found))

(define-read-only (get-project-metadata-url (project-id uint))
  (match (map-get? infrastructure-projects { id: project-id }) project
    (ok (get metadata-url project))
    err-project-not-found))

(define-read-only (is-maintainer (project-id uint) (who principal))
  (match (map-get? project-maintainers { id: project-id, maintainer: who }) entry
    (ok (get active entry))
    (ok false)))

(define-public (add-maintainer (project-id uint) (maintainer principal))
  (match (ensure-project-owner project-id) project
    (begin
      (match (map-get? project-maintainers { id: project-id, maintainer: maintainer }) existing
        (begin
          (map-set project-maintainers
            { id: project-id, maintainer: maintainer }
            { active: true })
          (ok true))
        (begin
          (map-insert project-maintainers
            { id: project-id, maintainer: maintainer }
            { active: true })
          (ok true))))
    err
    (err err)))

(define-public (remove-maintainer (project-id uint) (maintainer principal))
  (match (ensure-project-owner project-id) project
    (begin
      (match (map-get? project-maintainers { id: project-id, maintainer: maintainer }) existing
        (begin
          (map-set project-maintainers
            { id: project-id, maintainer: maintainer }
            { active: false })
          (ok true))
        (ok false)))
    err
    (err err)))

(define-read-only (get-rating-bounds)
  (ok { min: rating-min, max: rating-max }))

(define-read-only (get-owner-view)
  (get-owner))

(define-read-only (get-last-project-id-view)
  (get-last-project-id))

(define-read-only (get-current-height-view)
  (get-current-block-height))

(define-read-only (get-current-time-view)
  (get-current-block-time))

(define-read-only (get-project-info (project-id uint))
  (get-project project-id))

(define-read-only (get-project-trust-view (project-id uint))
  (get-project-trust-score project-id))

(define-read-only (get-project-ratings-count (project-id uint))
  (get-project-total-ratings project-id))

(define-read-only (get-has-rated-view (project-id uint) (rater principal))
  (has-rated project-id rater))

(define-read-only (get-rating-view (project-id uint) (rater principal))
  (get-project-rating-by project-id rater))

(define-read-only (get-project-owner-view (project-id uint))
  (get-project-owner project-id))

(define-read-only (get-project-name-view (project-id uint))
  (get-project-name project-id))

(define-read-only (get-project-url-view (project-id uint))
  (get-project-metadata-url project-id))

(define-read-only (is-contract-owner-view (who principal))
  (is-contract-owner who))

(define-read-only (is-project-owner-view (project-id uint) (who principal))
  (is-project-owner project-id who))

(define-read-only (is-maintainer-view (project-id uint) (who principal))
  (is-maintainer project-id who))

(define-read-only (get-total-projects)
  (ok (var-get last-project-id)))
