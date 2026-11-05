// Converts service terms between the backend's shape and the editor's form, both for the clinic's own terms and for
// what one professional changes from them (the backend's ServiceTermsPolicy). A professional's terms hold only what
// differs: an entry for a clinic service sets its own price or marks it not offered, an entry with a new id is a
// service only they offer, and an unset list of plans or payment methods means the clinic's.

export const PAYMENT_PIX = 0;

export const SERVICE_CHOICE = {
  INHERIT: 'inherit',
  OWN: 'own',
  NOT_OFFERED: 'notOffered',
};

const isUnset = value => value === null || value === undefined;

// Prices come from number inputs (a number or '') and from the backend (a number or null).
export const toPrice = value => {
  if (isUnset(value) || value === '') return null;
  const price =
    typeof value === 'number' ? value : Number(String(value).replace(',', '.'));
  return Number.isFinite(price) ? price : null;
};

const pixForm = methods => {
  const pix = (methods || []).find(method => method.type === PAYMENT_PIX)?.pix;
  return {
    enabled: !!pix,
    key: pix?.key || '',
    recipientName: pix?.recipientName || '',
  };
};

const pixMethods = pix =>
  pix.enabled
    ? [
        {
          type: PAYMENT_PIX,
          pix: { key: pix.key.trim(), recipientName: pix.recipientName.trim() },
        },
      ]
    : [];

const serviceRow = service => ({
  id: service.id,
  name: service.name || '',
  price: service.price ?? '',
  priceOnRequest: !!service.priceOnRequest,
});

// A row left completely empty is dropped rather than sent as a service with no name.
const isBlank = row =>
  !row.name.trim() && toPrice(row.price) === null && !row.priceOnRequest;

const offeredService = row => ({
  id: row.id,
  name: row.name.trim(),
  price: row.priceOnRequest ? null : toPrice(row.price),
  priceOnRequest: row.priceOnRequest,
  offered: true,
});

const trimmedList = list => list.map(item => item.trim()).filter(Boolean);

// crypto.randomUUID needs a secure context, such as HTTPS; getRandomValues does not. The backend reads any GUID.
const newId = () => {
  if (crypto.randomUUID) return crypto.randomUUID();
  const hex = Array.from(crypto.getRandomValues(new Uint8Array(16)), byte =>
    byte.toString(16).padStart(2, '0')
  ).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
};

export const newServiceRow = () => ({
  id: newId(),
  name: '',
  price: '',
  priceOnRequest: false,
});

export const toClinicForm = (terms = {}) => ({
  services: (terms.services || []).map(serviceRow),
  plans: [...(terms.acceptedPlans || [])],
  pix: pixForm(terms.paymentMethods),
  notes: terms.notes || '',
});

export const fromClinicForm = form => ({
  services: form.services.filter(row => !isBlank(row)).map(offeredService),
  acceptedPlans: trimmedList(form.plans),
  paymentMethods: pixMethods(form.pix),
  notes: form.notes.trim() || null,
});

const choiceFor = change => {
  if (!change) return SERVICE_CHOICE.INHERIT;
  if (change.offered === false) return SERVICE_CHOICE.NOT_OFFERED;
  return toPrice(change.price) !== null || change.priceOnRequest
    ? SERVICE_CHOICE.OWN
    : SERVICE_CHOICE.INHERIT;
};

export const toOverrideForm = (clinic = {}, terms = {}) => {
  const changes = new Map(
    (terms.services || []).map(service => [service.id, service])
  );
  const clinicServices = clinic.services || [];
  const clinicIds = new Set(clinicServices.map(service => service.id));
  return {
    services: clinicServices.map(service => {
      const change = changes.get(service.id);
      const choice = choiceFor(change);
      const own = choice === SERVICE_CHOICE.OWN;
      return {
        id: service.id,
        name: service.name || '',
        clinicPrice: service.price ?? null,
        clinicPriceOnRequest: !!service.priceOnRequest,
        choice,
        price: own ? (change.price ?? '') : '',
        priceOnRequest: own && !!change.priceOnRequest,
      };
    }),
    // Changes to services the clinic has since removed have no name of their own, so they are dropped.
    ownServices: (terms.services || [])
      .filter(
        service =>
          !clinicIds.has(service.id) &&
          service.offered !== false &&
          service.name
      )
      .map(serviceRow),
    // An own list starts from the clinic's plans, which is what the professional had until now.
    plans: {
      inherit: isUnset(terms.acceptedPlans),
      list: [...(terms.acceptedPlans ?? clinic.acceptedPlans ?? [])],
    },
    // An own Pix key never starts from the clinic's, which belongs to the clinic.
    payment: {
      inherit: isUnset(terms.paymentMethods),
      pix: pixForm(terms.paymentMethods),
    },
    notes: terms.notes || '',
  };
};

export const fromOverrideForm = form => ({
  services: [
    ...form.services.flatMap(row => {
      if (row.choice === SERVICE_CHOICE.NOT_OFFERED) {
        return [{ id: row.id, offered: false }];
      }
      const price = toPrice(row.price);
      // An own price left empty is the clinic's price, so nothing is stored for it.
      if (row.choice !== SERVICE_CHOICE.OWN) return [];
      if (price === null && !row.priceOnRequest) return [];
      return [
        {
          id: row.id,
          price: row.priceOnRequest ? null : price,
          priceOnRequest: row.priceOnRequest,
          offered: true,
        },
      ];
    }),
    ...form.ownServices.filter(row => !isBlank(row)).map(offeredService),
  ],
  acceptedPlans: form.plans.inherit ? null : trimmedList(form.plans.list),
  paymentMethods: form.payment.inherit ? null : pixMethods(form.payment.pix),
  notes: form.notes.trim() || null,
});
