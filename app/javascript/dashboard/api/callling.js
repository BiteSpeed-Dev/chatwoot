import axios from 'axios';
import ApiClient from './ApiClient';

class CallingAPI extends ApiClient {
  startCall({apiKey, token, subDomain, from, to, sid, callerId}) {
    const formData = new FormData();
    formData.append('To', to);
    formData.append('From', from) 
    formData.append('CallerId', callerId)
    formData.append('StatusCallback', 'http://localhost:3000')
    formData.append('StatusCallbackEvents', ['terminal', 'answered'])
    const url = `https://${apiKey}:${token}${subDomain}/v1/Accounts/${sid}/Calls/connect`
    return axios.post(
      url,
      formData
    )
  }
}

export default new CallingAPI();