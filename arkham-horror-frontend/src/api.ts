import axios from 'axios';

const token = localStorage.getItem('token');

if (token !== null && token !== undefined) {
  axios.defaults.headers.common.Authorization = `Token ${token}`;
}

export default axios.create({
  baseURL: 'http://localhost:3000/api/v1',
});
