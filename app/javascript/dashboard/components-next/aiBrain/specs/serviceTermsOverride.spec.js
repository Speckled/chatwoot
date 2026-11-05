import {
  PAYMENT_MERCADO_PAGO,
  PAYMENT_PIX,
  SERVICE_CHOICE,
  fromClinicForm,
  fromOverrideForm,
  newServiceRow,
  toClinicForm,
  toOverrideForm,
  toPrice,
} from '../serviceTermsOverride';

const CONSULTA = '0194a000-0000-7000-8000-000000000001';
const RETORNO = '0194a000-0000-7000-8000-000000000002';
const AVALIACAO = '0194a000-0000-7000-8000-000000000003';
const REMOVED = '0194a000-0000-7000-8000-000000000004';

const clinic = {
  services: [
    {
      id: CONSULTA,
      name: 'Consulta',
      price: 300,
      priceOnRequest: false,
      offered: true,
    },
    {
      id: RETORNO,
      name: 'Retorno',
      price: null,
      priceOnRequest: true,
      offered: true,
    },
  ],
  acceptedPlans: ['Unimed'],
  paymentMethods: [
    {
      type: PAYMENT_PIX,
      pix: { key: 'clinica@exemplo.com', recipientName: 'Clínica' },
    },
  ],
  notes: 'Chegue 10 minutos antes.',
};

describe('toPrice', () => {
  it('reads numbers, comma decimals and blanks', () => {
    expect(toPrice(150)).toBe(150);
    expect(toPrice('150,50')).toBe(150.5);
    expect(toPrice('')).toBeNull();
    expect(toPrice(null)).toBeNull();
    expect(toPrice('abc')).toBeNull();
  });
});

describe('clinic form', () => {
  it('round-trips the clinic terms', () => {
    expect(fromClinicForm(toClinicForm(clinic))).toEqual(clinic);
  });

  it('round-trips Mercado Pago next to the Pix key', () => {
    const terms = {
      ...clinic,
      paymentMethods: [
        ...clinic.paymentMethods,
        { type: PAYMENT_MERCADO_PAGO },
      ],
    };

    expect(toClinicForm(terms).mercadoPago).toBe(true);
    expect(fromClinicForm(toClinicForm(terms))).toEqual(terms);
  });

  it('drops blank rows and treats Pix off and empty notes as none', () => {
    const form = toClinicForm({});
    form.services.push(newServiceRow());
    form.plans = ['  ', ' Bradesco '];

    expect(fromClinicForm(form)).toEqual({
      services: [],
      acceptedPlans: ['Bradesco'],
      paymentMethods: [],
      notes: null,
    });
  });
});

describe('professional form', () => {
  const override = {
    services: [
      { id: CONSULTA, price: 350, priceOnRequest: false, offered: true },
      { id: RETORNO, offered: false },
      {
        id: AVALIACAO,
        name: 'Avaliação',
        price: 200,
        priceOnRequest: false,
        offered: true,
      },
      { id: REMOVED, price: 90, priceOnRequest: false, offered: true },
    ],
    acceptedPlans: [],
    paymentMethods: null,
    notes: null,
  };

  it('reads what a professional changes from the clinic', () => {
    const form = toOverrideForm(clinic, override);

    expect(form.services.map(row => row.choice)).toEqual([
      SERVICE_CHOICE.OWN,
      SERVICE_CHOICE.NOT_OFFERED,
    ]);
    expect(form.services[0]).toMatchObject({
      name: 'Consulta',
      clinicPrice: 300,
      price: 350,
    });
    expect(form.services[1]).toMatchObject({ clinicPriceOnRequest: true });
    expect(form.ownServices).toEqual([
      { id: AVALIACAO, name: 'Avaliação', price: 200, priceOnRequest: false },
    ]);
    expect(form.plans).toEqual({ inherit: false, list: [] });
    expect(form.payment.inherit).toBe(true);
  });

  it('writes back only what differs, dropping changes to removed services', () => {
    expect(fromOverrideForm(toOverrideForm(clinic, override))).toEqual({
      services: [
        { id: CONSULTA, price: 350, priceOnRequest: false, offered: true },
        { id: RETORNO, offered: false },
        {
          id: AVALIACAO,
          name: 'Avaliação',
          price: 200,
          priceOnRequest: false,
          offered: true,
        },
      ],
      acceptedPlans: [],
      paymentMethods: null,
      notes: null,
    });
  });

  it('treats an own price left empty as the clinic price', () => {
    const form = toOverrideForm(clinic, {});
    form.services[0].choice = SERVICE_CHOICE.OWN;

    expect(fromOverrideForm(form).services).toEqual([]);
    expect(form.plans).toEqual({ inherit: true, list: ['Unimed'] });
  });

  it('keeps own plans and a Pix key of their own once they stop following the clinic', () => {
    const form = toOverrideForm(clinic, {});
    form.plans.inherit = false;
    form.payment.inherit = false;

    expect(form.payment.pix).toEqual({
      enabled: false,
      key: '',
      recipientName: '',
    });
    form.payment.pix = {
      enabled: true,
      key: ' 12345678909 ',
      recipientName: ' Dra. Ana ',
    };

    expect(fromOverrideForm(form)).toMatchObject({
      acceptedPlans: ['Unimed'],
      paymentMethods: [
        {
          type: PAYMENT_PIX,
          pix: { key: '12345678909', recipientName: 'Dra. Ana' },
        },
      ],
    });
  });

  it('starts an own payment list with Mercado Pago when the clinic accepts it', () => {
    const withMercadoPago = {
      ...clinic,
      paymentMethods: [
        ...clinic.paymentMethods,
        { type: PAYMENT_MERCADO_PAGO },
      ],
    };
    const form = toOverrideForm(withMercadoPago, {});
    form.payment.inherit = false;

    expect(form.payment.mercadoPago).toBe(true);
    expect(fromOverrideForm(form).paymentMethods).toEqual([
      { type: PAYMENT_MERCADO_PAGO },
    ]);
    form.payment.mercadoPago = false;
    expect(fromOverrideForm(form).paymentMethods).toEqual([]);
  });
});
